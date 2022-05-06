import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);


const runDemo = async (GOAL) => {

 // const GOAL = stdlib.parseCurrency(100);

  const startingBalance = stdlib.parseCurrency(100);  

  const deadline = 50;
  const FUNDGOAL = stdlib.parseCurrency(GOAL);

  // Helper function for holding the balance of a participant
  const getBalance = async (who) => stdlib.parseCurrency(await stdlib.balanceOf(who), 4,);

  // Prints to console the amount that the funder intends to pay
  console.log(`Fund goal is set to ${stdlib.formatCurrency(FUNDGOAL)}`);

  // Creates receiver and funder test accounts with the starting balance
  const receiver = await stdlib.newTestAccount(startingBalance);
  const users = await stdlib.newTestAccounts(2, startingBalance);

  // Prints initial balance
  for ( const who of [ receiver, ...users ]) {
    console.warn(stdlib.formatAddress(who), 'has',
    stdlib.formatCurrency(await stdlib.balanceOf(who)));
  }

  // Receiver deploys the contract
  const ctcReceiver = receiver.contract(backend);

  // The try/catch is required for some reason.  Doesn't progress past
  // this line otherwise.
  try {
    await ctcReceiver.p.Receiver({
      receiverAddr: receiver.networkAccount,
      deadline: deadline,
      goal: FUNDGOAL,
      ready: () => {
        console.log('The contract is ready');
        throw 42;
      },
    });
  } catch (e) {
    if ( e !== 42) {
      throw e;
    }
  }

  // CONNECT TO CONTRACT
  const ctcWho = (whoi) => users[whoi].contract(backend, ctcReceiver.getInfo());
  // DONATE
  const donate = async (whoi, amount) => {
    const who = users[whoi];
    // Attatches the funder to the backend that the receiver deployed.
    const ctc = ctcWho(whoi);
    // Calls the donateToFund function from backend.
    console.log(stdlib.formatAddress(who), `donated ${stdlib.formatCurrency(amount)} to fund`);
    await ctc.apis.Funder.donateToFund(amount);
  };
  // TIMESUP
  const timesup = async () => {
    await ctcReceiver.apis.Bystander.timesUp();
    console.log('Deadline reached');
  };
  // GET OUTCOME
  const getoutcome = async () => {
    const outcome = await ctcReceiver.apis.Bystander.getOutcome();
    console.log(`Fund ${outcome? `did` : `did not`} meet its goal`);
    return outcome;
  };
  const paymeback = async (whoi) => {
    const who = users[whoi];
    // Attatches the funder to the backend that the receiver deployed.
    const ctc = ctcWho(whoi);
    // Calls the donateToFund function from backend.
    await ctc.apis.Funder.payMeBack();
    console.log(stdlib.formatAddress(who), `Got their funds back`);
  };


  // Test account user 0 donates 10 currency to fund.
  await donate(0, stdlib.parseCurrency(5));
  // Test account user 1 donates 1 currency to fund. 
  await donate(1, stdlib.parseCurrency(10));

  // Waits for the fund to mature
  console.log(`Waiting for the fund to reach the deadline`);
  await stdlib.wait(deadline);

  await timesup();
  const outcome = await getoutcome();

  // If the fund didn't meet its goal pay funders back
  if(!outcome){
    await paymeback(0);
    await paymeback(1);
  }


  // Prints the final balances of all accounts
  for ( const who of [ receiver, ...users ]) {
    console.warn(stdlib.formatAddress(who), 'has',
    stdlib.formatCurrency(await stdlib.balanceOf(who)));
  }

  console.log(`\n`);

}

await runDemo(10);
await runDemo(20);