import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);

const runDemo = async (PAYMENT) => {

  const stdlib = await loadStdlib();

  const startingBalance = stdlib.parseCurrency(100);  

  // Helper function for holding the balance of a participant
  const getBalance = async (who) => stdlib.formatCurrency(await stdlib.balanceOf(who), 4,); 
  

  const MATURITY = 10;
  const GOAL = stdlib.parseCurrency(10);


  const common = (who) => ({

    funded: async () => console.log(`${who} sees that the account is funded`),
    recvd : async () => console.log(`${who} received the funds.`),

    viewFundOutcome: async () => console.log(`${who} saw that the ${outcome ? `fund met its goal` : `fund did not meet its goal`}`),

    // TODO: I would like to be able to check the fund balance in the backend, but the
    // only way I can do this is by making this function to return the balance through
    // the front end.  Seems inefficient.  Need to find a way to access view variables
    // in backend.
    //viewFundBal: async () => v.Fund.balance,

    // DEBUGGING.  Prints the current balance of the contract.  Argument is a UInt from the balance() function on backend.
    //contBal: async (contractBalance) => console.log(`Contract has a balance of ${contractBalance}`)

  });

  // Prints to console the amount that the funder intends to pay
  console.log(`Funder will donate ${PAYMENT} currency to the fund`)

  // Creates receiver and funder test accounts
  // TODO: create multiple funder test accounts
  const receiver = await stdlib.newTestAccount(startingBalance);
  const funder = await stdlib.newTestAccount(startingBalance);

  // TODO: get a good understanding of what this is doing.  I get that it's attatching to the backend
  // but I don't know exactly what that means.
  const ctcReceiver = receiver.contract(backend);
  const ctcFunder = funder.contract(backend, ctcReceiver.getInfo());


  await Promise.all([
    backend.Receiver(ctcReceiver, {
      ...common('Receiver'),

      // Receiver specifies the details of the fund
      getParams: () => ({
        receiverAddr: receiver.networkAccount,
        maturity: MATURITY,
        goal: GOAL,
      }),

    }),
    backend.Funder(ctcFunder, {
      ...common('Funder'),

      // Funder specifies the amount that they want to pay
      getPayment: () => {
        return stdlib.parseCurrency(PAYMENT);
      },

    }),
  ]);


  // Prints the final balances of the Receiver and Funder account
  for(const [who, acc] of [['Receiver', receiver], ['Funder', funder]]) {
    let balance = await getBalance(acc);
    console.log(`${who} has a balance of ${balance}`);
  }


  console.log(`\n`);

};

// Runs the demo with the funder paying different amounts to the fund
await runDemo(0);
await runDemo(1);
await runDemo(10);
await runDemo(20);
