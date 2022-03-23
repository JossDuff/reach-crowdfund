import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);

const runDemo = async (delayReceiver, delayFunder) => {

  const stdlib = await loadStdlib();

  const startingBalance = stdlib.parseCurrency(100);  

  // Helper function for holding the balance of a participant
  const getBalance = async (who) => stdlib.formatCurrency(await stdlib.balanceOf(who), 4,); // Helper function for printing to console the balance of the contrac const contractBalance = async () =>  }
  
  const PAYMENT = 10;
  const MATURITY = 10;
  const REFUND = 10;
  const DORMANT = 10;
  const GOAL = 10;
  const fDelay = delayFunder ? MATURITY + REFUND + DORMANT + 1 : 0;
  const rDelay = delayReceiver ? MATURITY + REFUND + 1 : 0;
  console.log(`Begin demo with funder delay(${fDelay}) and receiver delay(${rDelay}).`);

  const common = (who, delay = 0) => ({
    funded: async () => {
      console.log(`${who} sees that the account is funded`);

      // Optionally cause a delay in the participant after they
      // receve the signal that the account is funded.
      if(delay != 0){
        console.log(`${who} begins to wait...`);
        await stdlib.wait(delay);
      }
    },
    ready : async () => console.log(`${who} is ready to receive the funds.`),
    recvd : async () => console.log(`${who} received the funds.`),

    // DEBUGGING.  Prints the current balance of the contract.  Argument is a UInt from the balance() function on backend.
    contBal: async (contractBalance) => console.log(`Contract has a balance of ${contractBalance}`)
  });

  const receiver = await stdlib.newTestAccount(startingBalance);
  const funder = await stdlib.newTestAccount(startingBalance);

  const ctcReceiver = receiver.contract(backend);
  const ctcFunder = funder.contract(backend, ctcReceiver.getInfo());


  await Promise.all([
    backend.Receiver(ctcReceiver, {
      ...common('Receiver', fDelay),
      getParams: () => ({
        receiverAddr: receiver.networkAccount,
        maturity: MATURITY,
        refund: REFUND,
        dormant: DORMANT,
        goal: GOAL,
      }),

    }),
    backend.Funder(ctcFunder, {
      ...common('Funder', rDelay),

      // Funder specifies the amount that they want to pay
      getPayment: () => {
        return stdlib.parseCurrency(PAYMENT);
      },

    }),
  ]);


  for(const [who, acc] of [['Receiver', receiver], ['Funder', funder]]) {
    let balance = await getBalance(acc);
    console.log(`${who} has a balance of ${balance}`);
  }


  console.log(`\n`);

};

await runDemo(false, false);
await runDemo(true, false);
await runDemo(true, true);

