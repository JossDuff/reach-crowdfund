
'reach 0.1';

// Common interface that has a series of signals for the different
// phases of the application: one for when the account is funded,
// one for when the particular participant is ready to extract
// the funds, and finally one for when they have successfully 
// received them.
const common = {
  funded: Fun([], Null),
  ready: Fun([], Null),
  recvd: Fun([UInt], Null), 
  seeOutcome: Fun([Bool], Null),

  // DEBUGGING function to return the balance of the contract at any point.
  // Intending for it to be public and callable by anyone so putting it here for now.
  // UInt is meant to be the result of the balance() function.  I'm assuming it's a UInt.
  // contBal: Fun([UInt], Null)
};

  // DEBUGGING: Paste wherever to check contract balance
  // Prints the balance of the contract before any funds are paid.  Should be 0. ASSERT?
  // Funder.interact.contBal(balance());

export const main = Reach.App(() => {
  const Receiver = Participant('Receiver', {
    // Specify receiver's interact interface here

    ...common,

    // Gets the parameters of a fund
    // By default, these values are local and private
    getParams: Fun([], Object({
      receiverAddr: Address,
      maturity: UInt,
      goal: UInt,
    })),
    
  });
  const Funder = Participant('Funder', {
    // Specify Funder's interact interface here

    ...common,

    // Get payment function.
    // Returns a UInt from frontend representing the amount 
    // of currency the funder wants to pay.
    getPayment: Fun([], UInt),

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

  // The consensus remembers who the Receiver is. 
  // Receiver.set(receiverAddr);
  commit();


  // Turns local private value 'payment' (UInt that is returned from getPayment function)
  // into a local public value by using declassify.
  Funder.only(()=>{
    const payment = declassify(interact.getPayment());
  });

  // Consensus step.  Makes 'payment' value known to all and Funder pays
  // that amount to the contract.
  Funder.publish(payment).pay(payment);


  commit();

  // Uses each to run the same code block 'only' in each of the
  // given participants.
  each([Funder, Receiver], () => {
    interact.funded();
  });


  // Everyone waits for the fund to mature
  wait(relativeTime(maturity));


  // TODO: It shouldn't matter who publishes this, is there any 
  // advantage/disadvantage to the receiver doing this?
  // Makes the variable contBal hold the current balance of the contract
  Receiver.only(()=>{
    const contBal = balance();
  });
  Receiver.publish(contBal);


  // Helper function to pay funder and receiver after the maturity of the fund
  const payOut = (Who) => {
    // TODO: if it's the funder, then send back their payment, if it's the receiver, 
    // pay the full amount that they raised.

    
    // Sends the payment amount to Who
    transfer(payment).to(Who);

    // Prints to the console that Who received their payment
    Who.only(()=>{
      interact.recvd(payment);
    });

    commit();


  };
 

  // TODO: I'm using the balance of the contract for now, but will have to change it to an 
  // individual balance for each active fund.

  // If the amount in the contract is greater than the goal amount, pay out to the receiver.
  const fundExpire = () =>{
    if(contBal >= goal){
      payOut(Receiver);
      return true;
    }
    else{
      payOut(Funder);
      return false;
    }
  };

  const outcome = fundExpire();

  each([Funder, Receiver], () => {
    interact.seeOutcome(outcome);
  });

  // TODO: might not want to exit here.  Put this here because I was trying to mimic
  // the logic from the "giveChance" function in workshop-trust-fund
  exit();

});

