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

    // For indicating to the frontend that the contract is deployed
    ready: Fun([], Null),
  });
  const Funder = API ('Funder', {
    // payFund function takes the amount that the funder wants
    // to donate to the fund as a UInt.
    donateToFund: Fun([UInt], Bool),

    // pays the funder back if the fund didn't reach the goal
    //payMeBack: Fun([], Bool),
  });
/*
  // API that assumes the role of anybody
  const Bystander = API ('Bystander', {
    viewOutcome: Fun([Bool], Null),
  });
*/

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

  const funders = new Map(Address, UInt);

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
      (payment, k) => { //removed k
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

  transfer(balance()).to(Receiver); // Pays the receiver

/*
  // If outcome is true then fund met its goal, so 
  // pay out to receiver
  if(outcome) {
    Receiver.interact.log("Fund met its goal")
    transfer(balance()).to(Receiver); // Pays the receiver
    Receiver.interact.log("Transfering ", balance(), " to Receiver");
    commit();
    Receiver.interact.log("Backend exiting.");
    exit();
  }
  // Otherwise, fund did not meet its goal and funds must
  // be paid back
  else {
    Receiver.interact.log("Fund did not meet its goal.  Funders can receiver their money back");
    const done = parallelReduce( false )
      .invariant(balance() >= 0)
      .while(! done && balance() >= 0)
      .api(Funder.payMeBack, 
        (k) => {
          // Gets funders donation
          const donation = fromSome(funders[this], 0);
          // Returns donation to funder
          transfer(donation).to(this);
          // Resets their amount donated to 0
          funders[this] = 0;
          // indicates successful function
          k(true);
          // indicates loop isn't done yet
          return false;
        }
      )
  }
*/
  commit();

  Receiver.interact.log("Backend exiting.");


  exit();

});