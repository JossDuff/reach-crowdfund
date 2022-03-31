
'reach 0.1';

// Common interface that has a series of signals for the different
// phases of the application: one for when the account is funded,
// one for when the particular participant is ready to extract
// the funds, and finally one for when they have successfully 
// received them.
const common = {
  funded: Fun([], Null),
  recvd: Fun([UInt], Null), 

  viewFundOutcome: Fun([Bool], Null),
  viewFundBal: Fun([UInt], Null), //TODO: check frontend implementation for full TODO.

};


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

  // Fund view for showing fund balance and success status.
  // Using a view here because fund balance and success staus
  // changes throughout execution.
  const vFund = View('Fund', {
    balance: UInt,
    success: Bool,
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

  // Updates fund view to reflect the new balance of the fund.
 // vFund.balance.set(payment);


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

  // TODO: if it's the funder, then send back their payment, if it's the receiver, 
  // pay the full amount that they raised.
  // TODO: I'm using the balance of the contract for now, but will have to change it to an 
  // individual balance for each active fund.

  const fundExpire = () =>{
    // TODO: find out how to access vFund.balance here instead of balance()
    // If the amount in the contract is greater than the goal amount, pay out to the receiver.
    if(balance() >= goal){
      return true;
    }
    else{
      return false;
    }
  };

  // Outcome is set to true if fund met or exceeded its goal, false otherwise.
  const outcome = fundExpire();

  // Updates fund success status.
  //vFund.success.set(outcome);

  // Funder and Receiver indicate they see the outcome.
  each([Funder, Receiver], () => {
    interact.viewFundOutcome(outcome);
  });


  // Initially had this as a function, but there was no reason for it to be a 
  // function at the time.
  if(outcome) { // True if the fund met its goal
    transfer(payment).to(Receiver); // Pays the receiver
    // Receiver indicates that they got paid.
    Receiver.only(()=>{
      interact.recvd(payment);
    });
  }
  else{ // If the fund didn't meet its goal.
    transfer(payment).to(Funder); // Pay the funder back
    // Funder indicates that they got paid.
    Funder.only(()=>{
      interact.recvd(payment);
    });
  }

  commit();


  exit();

});

