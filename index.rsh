
'reach 0.1';

// Common interface that has a series of signals for the different
// phases of the application: one for when the account is funded,
// one for when the particular participant is ready to extract
// the funds, and finally one for when they have successfully 
// received them.
/*
const common = {
  //funded: Fun([], Null), unsused
  recvd: Fun([UInt], Null), 

  viewFundOutcome: Fun([Bool], Null),

  // Anyone can call the timesUp function
  // TODO: might have to use, but unused for now.
  // timesUp: Fun([], Bool),
};
*/


export const main = Reach.App(() => {
  const Receiver = Participant('Receiver', {
    // Specify receiver's interact interface here

    //...common,

    // Gets the parameters of a fund
    // By default, these values are local and private
    getParams: Fun([], Object({
      receiverAddr: Address,
      maturity: UInt,
      goal: UInt,
    })),

    // For indicating to the frontend that the contract is deployed
    ready: Fun([], Null),
    
  });
  const Funder = API ('Funder', {
    //...common,
    
    // payFund function takes the amount that the funder wants
    // to donate to the fund as a UInt.
    // TODO: might also have to take an address to add to 
    // the mapping?
    donateToFund: Fun([UInt], Bool),
  });

  init();

  
  // Turns local private values (values in object from getParams) 
  // into local public values by using declassify.
  Receiver.only(() => {
    const {receiverAddr, maturity, goal} = declassify(interact.getParams());
  });


  // The funder publishes the parameters of the fund and makes the initial deposit.
  // Publish initiates a consensus step and makes the values known to all participants
  Receiver.publish(receiverAddr, maturity, goal);

  // Signals to the frontend that the contract is ready
  Receiver.interact.ready();

  const funders = new Map(Address, UInt);

  const [ keepGoing, fundBal ] =
  // fundBal starts at 0 and keepGoing starts as true.
  parallelReduce([ true, 0 ])
    // Define block allows you to define variables that are used in all the different cases.
    //.define({});
    // Loop invariant helps us know things that are true every time we enter and leave loop.
    .invariant(
      // true: mimicing RSPV example
      true
      // Balance in the contract is at least as much as the total amount in the fund
      && balance() >= fundBal
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
    // absoluteTime means this maturity number is expressed in terms of actual blocks.
    // Things in this block only happen after the maturity.
    .timeout( absoluteTime(maturity), () => {
      // TODO: maybe the receiver shouldn't publish this.  IDK.
      Receiver.publish();
      // returns false for keepGoing to stop the parallelReduce 
      return [ false, fundBal]
    });
 

  commit();


  // TODO: I'm using the balance of the contract for now, but will have to change it to an 
  // individual balance for each active fund.

  // Runs after fund expires and parallel reduce is exited

  // Outcome is set to true if fund met or exceeded its goal, false otherwise.
  const outcome = () => {
    if(balance() >= goal){
      return true;
    }
    else{
      return false;
    }
  }

  // TODO: functions to pay back funders or receivers

  // Initially had this as a function, but there was no reason for it to be a 
  // function at the time.
  if(outcome) { // True if the fund met its goal
    Receiver.publish();
    transfer(balance()).to(Receiver); // Pays the receiver

  }
  else{ // If the fund didn't meet its goal.
    
    // TODO: this probably won't work.  I want each funder to be able to retrieve their funds
    // whenever they want.  When a funder calls the function it returns the funds associated
    // with that funder.
    funders.forEach((addr) => {
      addr.publish();
      transfer(funders[addr].to(addr));
    });
  }

  commit();


  exit();

});

