/*
Problem analysis

1. Who is involved in this application?
    The investor and the fund creator.  

2. What information do they know at the start of the program?
    The investor knows the maturity of the funds and the identity of the fund creator. 
    fund creator knows the funding goal and fund maturity. 
     
3. What information are they going to discover and use in the program?


4. What funds change ownership during the application and how?
    
*/


'reach 0.1';

// Common interface that has a series of signals for the different
// phases of the application: one for when the account is funded,
// one for when the particular participant is ready to extract
// the funds, and finally one for when they have successfully 
// received them.
const common = {
  funded: Fun([], Null),
  ready: Fun([], Null),
  recvd: Fun([UInt], Null)
};

/*
STRUCT REFERENCE
const Posn = Struct([["x", UInt], ["y", UInt]]);
const p1 = Posn.fromObject({x: 1, y: 2});
const p2 = Posn.fromTuple([1, 2]);
*/

// Fund structure.  Variables are given by fund_creator
// TODO: change maturity from a UInt to a reach time function
// goal is the funds goal amount of currency.
// Investors is a mapping of everyone who invested in the project.  It maps a users
// address to a UInt of how much that user has invested.
// const Fund = Struct([
//   ["maturity", UInt], 
//   ["goal", UInt],
//   ["investors", Map]
// ]);


// Define the fund_creator interface
// Functions: Create fund, claim funds, cancel fund, view fund
const fund_creator = {
  // TODO: figure out proper data type for this.
  // Gotta research how to deal with time in Reach to signal the maturity of a fund
  maturity: UInt,

  // fundraiser goal.  If this amount of currency isn't in the contract by the
  // fund maturity then the currency in the fund is redistributed to the investors.
  goal: UInt,


};

// Define the investor interface
// Functions: invest in fund, view fund, withdraw investment, get investment
const investor = {

  // integer value 'investment' to hold amount to invest in a fund
  investment: UInt,

};




export const main = Reach.App(() => {
  const Receiver = Participant('Receiver', {
    // Specify receiver's interact interface here

    // receiver inherits the fund_creator and common interfaces
    ...fund_creator, 
    ...common,


    
  });
  const Funder = Participant('Funder', {
    // Specify Funder's interact interface here

    // Funder inherits the investor and common interfaces
    ...investor, 
    ...common,

    // Gets the parameters of a fund
    getParams: Fun([], Object({
      receiverAddr: Address,
      payment: UInt,
      maturity: UInt,
      refund: UInt,
      dormant: UInt
    })),

  });
  const Bystander = Participant('Bystander', {
    // Specify Receiver's interact interface here
    ...common,
  });


  init();

  Funder.only(() => {
    const {receiverAddr, payment, maturity, refund, dormant }
      = declassify(interact.getParams());
  });

  // 1. The funder publishes the parameters of the fund and makes
  // the initial deposit.
  Funder.publish(receiverAddr, payment, maturity, refund, dormant )
    .pay(payment);

  // 2. The consensus remembers who the Receiver is. 
  Receiver.set(receiverAddr);
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
    Receiver,
    { deadline: refund,
      after: () =>
      giveChance(
        Funder,
        { deadline: dormant,
          after: () =>
          giveChance(Bystander, false) })
      }); });

