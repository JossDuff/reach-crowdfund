import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);


const runDemo = async (GOAL) => {

  const startingBalance = stdlib.parseCurrency(100);

  // Set for testing purposes.
  const deadline = 50;
  const FUNDGOAL = stdlib.parseCurrency(GOAL);

  // Helper function for holding the balance of a participant
  const getBalance = async (who) => stdlib.parseCurrency(await stdlib.balanceOf(who), 4,);

  // Prints to console the fund goal.
  console.log(`Fund goal is set to ${stdlib.formatCurrency(FUNDGOAL)}`);

  // Creates receiver and 2 funder test accounts with the starting balance.
  const receiver = await stdlib.newTestAccount(startingBalance);
  const users = await stdlib.newTestAccounts(2, startingBalance);

  // Prints initial balance of the 3 accounts
  for ( const who of [ receiver, ...users ]) {
    console.warn(stdlib.formatAddress(who), 'has',
    stdlib.formatCurrency(await stdlib.balanceOf(who)));
  }

  // Receiver deploys the contract
  const ctcReceiver = receiver.contract(backend);

  // Since the receiver doesn't need to do anything after
  // deploying the contract and fund, we can shut off their thread.
  // This can be done in Reach by using a try/catch block
  // and throwing an arbitrary error.
  // Inspiration from Jay McCarthy's session at Reach Summit 2022:
  // https://www.youtube.com/watch?v=rhgEUFjiI2s&t=5158s
  try {
    await ctcReceiver.p.Receiver({
      receiverAddr: receiver.networkAccount,
      deadline: deadline,
      goal: FUNDGOAL,
      // Defines the receivers ready() function.
      ready: () => {
        console.log('The contract is ready');
        // Arbitrary error.
        throw 42;
      },
    });
  } catch (e) {
    if ( e !== 42) {
      throw e;
    }
  }

  // Helper function to connect and address to the contract.
  const ctcWho = (whoi) => users[whoi].contract(backend, ctcReceiver.getInfo());

  // Helper function to connect an address to the contract and call
  // the contracts donateToFund function.
  const donate = async (whoi, amount) => {
    const who = users[whoi];
    // Attatches the funder to the backend that the receiver deployed.
    const ctc = ctcWho(whoi);
    // Calls the donateToFund function from backend.
    console.log(stdlib.formatAddress(who), `donated ${stdlib.formatCurrency(amount)} to fund`);
    await ctc.apis.Funder.donateToFund(amount);
  };

  // Helper function to call the contract's timesUp function.
  const timesup = async () => {
    await ctcReceiver.apis.Bystander.timesUp();
    console.log('Deadline reached');
  };

  // Helper function to call the contract's getOutcome function
  // and publish it to the frontend.
  const getoutcome = async () => {
    const outcome = await ctcReceiver.apis.Bystander.getOutcome();
    console.log(`Fund ${outcome? `did` : `did not`} meet its goal`);
    return outcome;
  };

  // Helper function to connect an address to the contract and
  // call the contract's payMeBack function.
  const paymeback = async (whoi) => {
    const who = users[whoi];
    // Attatches the funder to the backend that the receiver deployed.
    const ctc = ctcWho(whoi);
    // Calls the donateToFund function from backend.
    await ctc.apis.Funder.payMeBack();
    console.log(stdlib.formatAddress(who), `got their funds back`);
  };


  // Test account user 0 donates 5 currency to fund.
  await donate(0, stdlib.parseCurrency(5));

  // Test account user 1 donates 10 currency to fund.
  await donate(1, stdlib.parseCurrency(10));

  // Waits for the fund to mature
  console.log(`Waiting for the fund to reach the deadline`);
  await stdlib.wait(deadline);

  // Anyone calls the timesUp function to indicate the
  // contract has reached the deadline.
  await timesup();

  // Gets the outcome of the fund.
  // True if fund met its goal, false otherwise.
  const outcome = await getoutcome();

  // If the fund didn't meet its goal, funders call
  // function to get their funds back.
  if(!outcome){
    // Test account user 0 requests their donation back.
    await paymeback(0);
    // Test account user 1 requests their donation back.
    await paymeback(1);
  }


  // Prints the final balances of all accounts
  for ( const who of [ receiver, ...users ]) {
    console.warn(stdlib.formatAddress(who), 'has',
    stdlib.formatCurrency(await stdlib.balanceOf(who)));
  }

  console.log(`\n`);

}

// Runs the demo with a fund goal of 10.
await runDemo(10);
// Runs the demo with a fund goal of 20.
await runDemo(20);
