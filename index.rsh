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
const Fund = Struct([
  ["maturity", UInt], 
  ["goal", UInt],
  ["investors", map]
]);


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
  const Receiver = Participant('receiver', {
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


  init();

  // The first one to publish deploys the contract
  Receiver.publish();
  commit();

  // States that this block of code is something that ONLY Funder
  // performs.  This means that the variable 'investment' is known
  // only to Funder.
  Funder.only(() => {

    // Declassift the investment for transmission
    const investment = declassify(interact.investment);

  });

  // The second one to publish always attaches
  Funder.publish(investment)
    .pay(investment);


  transfer(investment).to(Receiver);

  
  commit();

  // write your program here
  exit();
});
