'reach 0.1';


export const main = Reach.App(() => {
  const Receiver = Participant('Receiver', {
    ...hasConsoleLogger,
    // Specify receiver's interact interface here

    // Gets the parameters of a fund
    // By default, these values are local and private
    receiverAddr: Address,
    deadline: UInt,
    goal: UInt,

    // initial payment of the fund so there's gas to pay back funders
    initialPayment: UInt,

    // For indicating to the frontend that the contract is deployed
    ready: Fun([], Null),
  });
  const Funder = API ('Funder', {
    // payFund function takes the amount that the funder wants
    // to donate to the fund as a UInt.
    donateToFund: Fun([UInt], Bool),

    // pays the funder back if the fund didn't reach the goal
    payMeBack: Fun([], Bool),
  });


  init();

  
  // Turns local private values (values in object from getParams) 
  // into local public values by using declassify.
  Receiver.only(() => {
    const receiverAddr = declassify(interact.receiverAddr);
    const deadline = declassify(interact.deadline);
    const goal = declassify(interact.goal);
  });

  // The funder publishes the parameters of the fund and makes the initial deposit.
  // Publish initiates a consensus step and makes the values known to all participants
  Receiver.publish(receiverAddr, deadline, goal);

  // Committing here so we can use relativeTime
  commit();
  Receiver.publish();

  // Indicate to the frontend that the fund is ready
  Receiver.interact.ready();

  const deadlineBlock = relativeTime(deadline);

  // New mapping to keep track of addresses that donate to the fund
  // Default key value is Address
  // Mapping of addresses to UInt
  const funders = new Map(UInt);

  const [ keepGoing, fundBal ] =
  // fundBal starts at 0 and keepGoing starts as true.
  parallelReduce([ true, 0 ])
    // Define block allows you to define variables that are used in all the different cases.
    //.define({});
    // Loop invariant helps us know things that are true every time we enter and leave loop.
    .invariant(
      // Balance in the contract is at least as much as the total amount in the fund
      balance() >= fundBal
    )
    .while( keepGoing )
    .api(Funder.donateToFund,
      // Takes the payment as an argument and makes them pay that amount to contract.
      // "Pay expression"
      (payment) => payment,

      // Increments the variable for keeping track of the total amount they paid.
      (payment, k) => {
        // Indicates the api call was successful
        k(true);
        
        // Adds the funder to the funders mapping

        // If it's the funders first time, add them and their donation to the mapping
        if(isNone(funders[this])){
          funders[this] = payment;
        }
        // Otherwise, they already are in the mapping so just update their payment
        else {
          // Resolves the Maybe(UInt) from the mapping to a UInt
          const oldDono = fromSome(funders[this], 0);
          const newDono = oldDono + payment;
          funders[this] = newDono;
        }

        // has the parallel reduce keep going with the updated fundBal
        return [ keepGoing, fundBal + payment ];

      }
    )
    // absoluteTime means this deadline number is expressed in terms of actual blocks.
    // Things in this block only happen after the deadline.
    .timeout( deadlineBlock, () => {
      // Anybody is shorthand for a race.
      Anybody.publish();
      // returns false for keepGoing to stop the parallelReduce 
      return [ false, fundBal]
    });

  // Outcome is true if fund met or exceeded its goal
  // Outcome is false if the fund did not meet its goal
  const outcome = fundBal >= goal;

  commit();
  Receiver.publish();

  if(outcome){
    transfer(balance()).to(Receiver); // Pays the receiver
    commit();
    exit();
  }

  assert(outcome == false);

  // TODO: might need to check if a caller didn't already donate
  const [ done, fundsRemaining ] = 
    parallelReduce([ false, fundBal ])
    .define(() => {
      const checkDonation = (who) => {
        // Gets the UInt associated with the address in mapping
        const dono = fromSome(funders[who], 0);
//        require( dono != 0, "Caller has funds to claim.");
        // Transfers the amount the funder donated
        transfer(dono).to(who);
        // Sets the amount the funder donated to 0 after they
        // received their funds back
        funders[who] = 0;
        // Keeps loop going and returns the new fundsRemaining 
        return [ done, fundsRemaining - dono ];
      };
    })
    .invariant(balance() >= fundsRemaining)
    .while( !done && fundsRemaining > 0 )
    .api(Funder.payMeBack,
      (k) => {
        k(true);
        return checkDonation(this);
      }
    );
  
  
  /*
  In the situation where someone sends currency to this contract address
  by a simple transaction rather than by the donateToFund function
  the contract balance would be higher than fundBal or fundRemaining.  
  Since we can't prevent someone sending currency to an address, we will
  consider all these "external" transactions as donations to the fund 
  that don't expect to be paid back.  The amount left in the contract after
  the payMeBack parallel reduce ends is the balance that was "externally" 
  transferred to the contract and will be paid back to the funder.
  */

  // Any excess funds left over are considered "donations"
  // to the fund that the receiver gets back.
  transfer(balance()).to(Receiver);
  
  commit();

  exit();

});