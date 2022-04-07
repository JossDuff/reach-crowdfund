import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);


const runDemo = async (GOAL) => {

  const stdlib = await loadStdlib();

  const startingBalance = stdlib.parseCurrency(100);  

  const FUNDMATURITY = 10;
  const FUNDGOAL = stdlib.parseCurrency(GOAL);


  const common = (who) => ({

    //funded: async () => console.log(`${who} sees that the account is funded`), unused
    recvd : async () => console.log(`${who} received the funds.`),
    viewFundOutcome: async (outcome) => console.log(`${who} saw that the ${outcome ? `fund met its goal` : `fund did not meet its goal`}`),
  });

  // Prints to console the amount that the funder intends to pay
  console.log(`Fund goal is set to ${GOAL}.`);

  // Creates receiver and funder test accounts with the starting balance
  const receiver = await stdlib.newTestAccount(startingBalance);
  const users = await stdlib.newTestAccounts(5, startingBalance);

  // Receiver deploys the contract
  const ctcReceiver = receiver.contract(backend);

  await Promise.all([
    backend.Receiver(ctcReceiver, {
      ...common('Receiver'),

      // Receiver specifies the details of the fund
      getParams: () => ({
        receiverAddr: receiver.networkAccount,
        maturity: FUNDMATURITY,
        goal: FUNDGOAL,
      }),

    }),
  ]);

  const donate = async (whoi, amount) => {
    const who = users[whoi];
    // Attatches the funder to the backend that the receiver deployed.
    const ctc = who.contract(backend, ctcReceiver.getInfo);
    // Calls the donateToFund function from backend.
    await ctc.apis.Funder.donateToFund(amount);
    console.log(`${who} donated ${amount} to fund`);
  };


  // Test account user 0 donates 10 currency to fund.
  await donate(0, 10);
  // Test account user 1 donates 1 currency to fund. 
  await donate(1, 1);

  // Waits for the fund to mature
  console.log(`Waiting for the fund to reach the deadline.`);
  await stdlib.wait(FUNDMATURITY);
  
  // Prints the final balances of all accounts
  for ( const who of [ accD, ...users ]) {
    console.warn(who, 'has', stdlib.formatCurrency(await stdlib.balanceOf(who)));
  }

  console.log(`\n`);

};


// Runs the demo with different fund goal amounts
await runDemo(1);
await runDemo(10);
await runDemo(100);