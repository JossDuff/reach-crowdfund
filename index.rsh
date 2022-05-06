'reach 0.1';


export const main = Reach.App(() => {
  const Receiver = Participant('Receiver', {
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
    payMeBack: Fun([], Bool),
  });
  // API that assumes the role of anybody
  const Bystander = API ('Bystander', {
    timesUp: Fun([], Bool),
    printOutcome: Fun([], Bool),
    printFundBal: Fun([], UInt),
    printGoal: Fun([], UInt),
    printBalance: Fun([], UInt),
    printBalanceAgain: Fun([], UInt),
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

  const funders = new Map(Address, UInt);

  const [ keepGoing, fundBal ] =
  // fundBal starts at 0 and keepGoing starts as true.
  parallelReduce([ true, 0 ])
    // Define block allows you to define variables that are used in all the different cases.
    .define(()=>{
      const checkDonateToFund = (who, donation) => {
        // TODO: allow funders to donate multiple times
        check( isNone(funders[this]), "Not yet donated" );
        return () => {
          funders[who] = donation;
          return [ keepGoing, (fundBal + donation) ];
        };

      };
    })
    // Loop invariant helps us know things that are true every time we enter and leave loop.
    .invariant(
      // Balance in the contract is at least as much as the total amount in the fund
      balance() >= fundBal
    )
    .while( keepGoing )
    .api(Funder.donateToFund,
      (payment) => { const _ = checkDonateToFund(this, payment); },
      // Pay expression
      (payment) => payment,
      (payment, k) => {
        k(true);
        return checkDonateToFund(this, payment)();
      }
    )
    // absoluteTime means this deadline number is expressed in terms of actual blocks.
    // Things in this block only happen after the deadline.
    .timeout( deadlineBlock, () => {

      const [ [], k ] = call(Bystander.timesUp);
      k(true);

      // returns false for keepGoing to stop the parallelReduce 
      return [ false, fundBal ]; 
    });

  assert( fundBal <= balance() );

  // Outcome is true if fund met or exceeded its goal
  // Outcome is false if the fund did not meet its goal
  const outcome = fundBal >= goal;

  commit();

  const [ [], u ] = call(Bystander.printOutcome);
  u(outcome);

  commit();

  const [ [], j ] = call(Bystander.printFundBal);
  j(fundBal);

  commit();

  const [ [], p ] = call(Bystander.printBalance);
  p(balance());
  
  commit();

  const [ [], o ] = call(Bystander.printGoal);
  o(goal);

  commit();


  const checkPayMeBack = (who) => {
    check( !isNone(funders[who]), "Funder exists in mapping");
    return () => {
      const amount = balance();
      transfer(amount).to(who);
      /*
      const dono = fromSome(funders[who], 0);
      transfer(dono).to(who);
      funders.remove(who);
*/
    }
  }

/*
  if(outcome) {
    transfer(balance()).to(Receiver); // Pays the receiver
    commit();
    exit();
  }

  assert(outcome == false);
*/

  fork().api(Funder.payMeBack,
    () => { const _ = checkPayMeBack(this); },
    () => 0,
    (k) => {
      k(true);
    }
  );



  transfer(balance()).to(Receiver);
  commit();

  const [ [], b ] = call(Bystander.printBalanceAgain);
  b(balance());
  commit();

  exit();

});