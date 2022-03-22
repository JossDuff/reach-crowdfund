
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

  // DEBUGGING function to return the balance of the contract at any point.
  // Intending for it to be public and callable by anyone so putting it here for now.
  // UInt is meant to be the result of the balance() function.  I'm assuming it's a UInt.
  contBal: Fun([UInt], Null)
};

  // DEBUGGING: Paste wherever to check contract balance
  // Prints the balance of the contract before any funds are paid.  Should be 0. ASSERT?
  // Funder.interact.contBal(balance());

export const main = Reach.App(() => {
  const Receiver = Participant('Receiver', {
    // Specify receiver's interact interface here

    ...common,

    // Gets the parameters of a fund
    getParams: Fun([], Object({
      receiverAddr: Address,
      payment: UInt,
      maturity: UInt,
      refund: UInt,
      dormant: UInt,
      goal: UInt 
    })),
    
  });
  const Funder = Participant('Funder', {
    // Specify Funder's interact interface here

    ...common,

  });
  const Bystander = Participant('Bystander', {
    // Specify Receiver's interact interface here
    ...common,
  });


  init();

  Receiver.only(() => {
    const {receiverAddr, payment, maturity, refund, dormant }
      = declassify(interact.getParams());
  });


  // The funder publishes the parameters of the fund and makes
  // the initial deposit.
  Receiver.publish(receiverAddr, payment, maturity, refund, dormant );

  // The consensus remembers who the Receiver is. 
  // Receiver.set(receiverAddr);
  commit();

  // The funder pays the amount specified by the receiver from frontend to the contract
  Funder.pay(payment);

  commit();

  // Uses each to run the same code block 'only' in each of the
  // given participants.
  each([Funder, Receiver, Bystander], () => {

    interact.funded();
  });

  // 3. Everyone waits for the fund to mature
  wait(relativeTime(maturity));

  // Define the function as one that abstracts over who is permitted
  // to extract the funds and whether there is a deadline.
  const giveChance = (Who, then) => {
    Who.only(() => interact.ready());

    if(then){
      Who.publish()
        .timeout(relativeTime(then.deadline), () => then.after());
    } else {
      Who.publish();
    }
    transfer(payment).to(Who);
    commit();
    Who.only(() => interact.recvd(payment));
    exit();
  };

  // abstract the duplicate copied repeated structure of the program
  // into three calls to the same function.
  giveChance(
    Funder,
    { deadline: refund,
      after: () =>
      giveChance(
        Receiver,
        { deadline: dormant,
          after: () =>
          giveChance(Bystander, false) })
      }); });

