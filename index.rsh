'reach 0.1';

export const main = Reach.App(() => {

  // Receiver is the address creating the fund to receive currency
  // It is the only participant
  const Receiver = Participant('Receiver', {

    // Gets the parameters of a fund
    // By default, these values are local and private
    receiverAddr: Address,
    deadline: UInt,
    goal: UInt,

    // For indicating to the frontend that the contract is deployed
    // and the fund is ready to receive payments.
    ready: Fun([], Null),
  });

  // Funder API for any address to use.
  // For donating to and getting money back (if fund doesn't reach
  // its goal) from a fund
  const Funder = API ('Funder', {

    // payFund function takes the amount that the funder wants
    // to donate to the fund as a UInt.
    donateToFund: Fun([UInt], Bool),

    // Pays the funder back if the fund didn't reach the goal.
    // Returns the amount the funder previously donated.
    payMeBack: Fun([], Bool),
  });

  // Bystander API for any address to use.
  const Bystander = API ('Bystander', {
    // Indicates that the fund has reached its deadline.
    timesUp: Fun([], Bool),
    // For displaying whether or not fund met its goal.
    getOutcome: Fun([], Bool),
  });


  init();


  // Receiver declassifies details of the fund.
  Receiver.only(() => {
    const receiverAddr = declassify(interact.receiverAddr);
    const deadline = declassify(interact.deadline);
    const goal = declassify(interact.goal);
  });

  // The funder publishes the parameters of the fund to the
  // blockchain.
  // Publish initiates a consensus step and makes the values
  // known to all participants.
  Receiver.publish(receiverAddr, deadline, goal);

  commit();
  Receiver.publish();

  // Indicate to the frontend that the fund is ready.
  Receiver.interact.ready();

  // Mapping to keep track of amount that each address donates
  // to the fund.
  const funders = new Map(Address, UInt);
  // Set for tracking which addresses have donated.
  // Used verifying an address has donated in the payMeBack
  // function.
  const fundersSet = new Set();


  // ParallelReduce to allow for any address to donate to a fund.
  // Address can donate until fund deadline is reached.
  const [ keepGoing, fundBal, numFunders ] =
  // fundBal and numFunders starts at 0 and keepGoing starts as true.
  parallelReduce([ true, 0, 0 ])
    // Define block allows you to define variables/functions that
    // are used in the different cases.
    .define(()=>{
      const checkDonateToFund = (who, donation) => {
        // Checks that the funder hasn't donated yet
        // For some practice, try to implement functionality
        // for funders to donate multiple times.
        //check( isNone(funders[this]), "Not yet in map" );
        check( !fundersSet.member(who), "Not yet in set");
        // Doesn't allow donations of 0
        check( donation != 0, "Donation equals 0");
        return () => {
          // Adds the funder to the mapping with their donation.
          funders[who] = donation;
          // Adds the funder to the set of funders.
          fundersSet.insert(who);
          // Continues the parallel reduce with the new fund balance
          // and number of funders.
          return [ keepGoing, fundBal + donation, numFunders + 1 ];
        };
      };
    })
    // Loop invariant helps us know things that are true every time
    // we enter and leave loop.
    .invariant(
      // Balance in the contract is at least as much as the total
      // amount in the fund
      balance() >= fundBal
      // The number of funders in the map is the same as the
      // number of funders tracked by the parallel Reduce.
      && fundersSet.Map.size() == numFunders
    )
    .while( keepGoing )
    // API function for any address to call as a funder to
    // donate to the fund.  Is called with 'payment' UInt
    // indicating the amount of network currency they want
    // to donate.
    .api(Funder.donateToFund,

      // Runs the checks in checkDonateToFund function define in
      // .define() block of this parallel Reduce.
      (payment) => { const _ = checkDonateToFund(this, payment); },

      // Pay expression.  Requests 'payment' amount from funder
      // and deposits into the contract.
      (payment) => payment,

      (payment, k) => {
        // Returns true for the API call, indicating it was successful.
        k(true);
        // Calls the function within checkDonateToFund to update the
        // funder mapping, funder set, and parallel Reduce.
        return checkDonateToFund(this, payment)();
      }
    )
    // Things in this block only happen after the deadline.
    .timeout( relativeTime(deadline), () => {

      // Any bystander calls the timesUp function, indicating the
      // parallel reduce has finised and the fund reached its deadline.
      const [ [], k ] = call(Bystander.timesUp);
      // Returns true for the timesUp API call, indicating it was successful.
      k(true);

      // Returns false for keepGoing to stop the parallelReduce.
      return [ false, fundBal, numFunders ];
    });


  // Check to ensure that the balance in the contract is always
  // greater than or equal to the calculated balance of the fund.
  assert( fundBal <= balance() );



  // Outcome is true if fund met or exceeded its goal
  // Outcome is false if the fund did not meet its goal
  const outcome = fundBal >= goal;

  commit();

  // Bystander views the outcome of the fund.
  const [ [], u ] = call(Bystander.getOutcome);
  // Returns outcome.
  u(outcome);

  // If the fund met or exceeded its goal, pay all the money
  // in the contract to the Receiver.
  if(outcome) {
    // Pays the receiver.
    transfer(balance()).to(Receiver);
    commit();
    exit();
  }

  // If the contract is at this point that must mean the fund
  // did not meet its goal and the funders must receive their
  // currency back.
  assert(outcome == false);

  // ParallelReduce to allow for any address that previously donated
  // to call a function to receive their funds back.
  const [ fundsRemaining, numFundersRemaining ] =
    parallelReduce([ fundBal, numFunders ])
    .define(()=> {
      const checkPayMeBack = (who) => {
        // Check that the address previously donated and is in the
        // mapping and set.
        check( !isNone(funders[who]), "Funder exists in mapping");
        check( fundersSet.member(who), "Funder exists in set");
        // Unwraps the UInt (amount doated) of the address in
        // the mapping.
        const amount = fromSome(funders[who], 0);
        check( amount != 0, "Amount doesn't equal 0");
        // Checks there is enough currency in the contract to
        // pay back funder.
        check(balance() >= amount);
        return () => {
          // Transfers back the amount the funder previously
          // donated
          transfer(amount).to(who);
          // Removes the funder from the set and sets their
          // mapping to 0.
          funders[who] = 0;
          fundersSet.remove(who);
          // Continue parallel reduce.
          return [ fundsRemaining-amount, numFunders-1];
        }
      }
    })
    .invariant(
      // Ensures the balance of the contract is equal
      // to or greater than the amount of funds remaining
      // in the contract.
      balance() >= fundsRemaining
    )
    // Loop continues until either there are no funds remaining
    // or all funders reclaimed their funds.
    .while( fundsRemaining > 0 && numFundersRemaining > 0)
    // API for any address to call to attempt to re-claim
    // their previous donation.
    .api(Funder.payMeBack,
      // Runs the checks in the checkPayMeBack function
      // from the .define() block.
      () => {const _ = checkPayMeBack(this); },
      // Pay expression is 0 because we don't want
      // function callers to pay anything for this.
      () => 0,
      (k) => {
        // Returns true for the payMeBack API call,
        // indicating it was successful.
        k(true);
        // Calls the inner function in checkPayMeBack,
        // transfering the funds back to the receiver.
        return checkPayMeBack(this)();
      }
    )


  // FINAL EXTRA BALANCE
  // Since a contract is just an address on a blockchain,
  // anyone can send funds to it at any time.  Any funds
  // sent to this contract's address without using the
  // donateToFund function aren't tracked and thus nobody
  // can re-claim them during the "pay me back" period
  // if the fund doesn't reach its goal.
  // Sending funds in this manner is viewed as a free
  // donation to the receiver that isn't expecting to
  // be paid back.

  // This transfers out any remaining balance to ensure
  // that no funds are permanently locked in the contract.
  transfer(balance()).to(Receiver);
  commit();


  exit();

});
