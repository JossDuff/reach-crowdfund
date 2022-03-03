'reach 0.1';

// Fund object
// TODO: implement a Map
// TODO: change maturity to one of Reach's time arguments
const fundObj = Object({
  goal: UInt,
  maturity: UInt,
  // receiverAddr: Address,
  // payment: UInt,
  // maturity: UInt,
  // refund: UInt,
  // dormant: UInt
});

// Common interface that has a series of signals for the different
// phases of the application: one for when the account is funded,
// one for when the particular participant is ready to extract
// the funds, and finally one for when they have successfully 
// received them.
// const common = {
//   funded: Fun([], Null),
//   ready: Fun([], Null),
//   recvd: Fun([UInt], Null)
// };

export const main = Reach.App(() => {
  const A = Participant('Alice', {
    // ...common,
    ...hasRandom,
    // Specify Alice's interact interface here

    // gets/sets the object
    getObj: Fun([], fundObj),
  });
  const B = Participant('Bob', {
    // ...common,
    // Specify Bob's interact interface here

    // Prints out fund object
    showObj: Fun([fundObj], Null),
  });
  init();

  A.only(()=>{
    const obj = declassify(interact.getObj());
  });

  // The first one to publish deploys the contract
  A.publish(obj);
  commit();
  // The second one to publish always attaches
  B.publish();
  commit();

  B.only(()=>{
    interact.showObj(obj);
  });

  // write your program here
  exit();
});
