import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);


const runDemo = async (GOAL) => {


  const startingBalance = stdlib.parseCurrency(100);  

  const FUNDDEADLINE = 250;
  const FUNDGOAL = stdlib.parseCurrency(GOAL);

  // Helper function for holding the balance of a participant
  const getBalance = async (who) => stdlib.formatCurrency(await stdlib.balanceOf(who), 4,);

  // Prints to console the amount that the funder intends to pay
  console.log(`Fund goal is set to ${GOAL}.`);

  // Creates receiver and funder test accounts with the starting balance
  const receiver = await stdlib.newTestAccount(startingBalance);
  const users = await stdlib.newTestAccounts(5, startingBalance);

  // Receiver deploys the contract
  const ctcReceiver = receiver.contract(backend);

  await Promise.all([
    backend.Receiver(ctcReceiver, {
    ...stdlib.hasConsoleLogger,
      // Receiver specifies the details of the fund
      
      receiverAddr: receiver.networkAccount,
      deadline: FUNDDEADLINE,
      goal: FUNDGOAL,

      ready : async () => console.log(`Fund is ready to receive donations.`),
    }),
  ]);

  const ctcWho = (whoi) => users[whoi].contract(backend, ctcReceiver.getInfo());

  const donate = async (whoi, amount) => {
    const who = users[whoi];
    // Attatches the funder to the backend that the receiver deployed.
    const ctc = ctcWho(whoi);
    // Calls the donateToFund function from backend.
    await ctc.apis.Funder.donateToFund(amount);
    console.log(`${who} donated ${amount} to fund`);
  };


  // Test account user 0 donates 10 currency to fund.
  await donate(0, 1);
  // Test account user 1 donates 1 currency to fund. 
  await donate(1, 1);

  // Waits for the fund to mature
  console.log(`Waiting for the fund to reach the deadline.`);
  await stdlib.wait(FUNDDEADLINE);


  // Prints the final balances of all accounts
  for ( const acc of [ receiver, ...users ]) {
    let balance = await getBalance(acc);
    console.log(`${acc} has a balance of ${balance}`);
  }

  console.log(`\n`);

};


// Runs the demo with different fund goal amounts
await runDemo(1);
await runDemo(10);
await runDemo(100);