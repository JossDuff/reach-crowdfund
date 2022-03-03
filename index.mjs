import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);

(async () => {

  // FUND VARIABLES
  // const MATURITY = 10;
  // const REFUND = 10;
  // const DORMANT = 10;
  // const fDelay = MATURITY + REFUND + DORMANT + 1;
  // const rDelay = MATURITY + REFUND + 1;
  // console.log(`Begin demo with funder delay(${fDelay}) and receiver delay(${rDelay}).`);
// 
  // Common interface implementation
  // const common = (who, delay = 0) => ({
  //   funded: async () => {
  //     console.log(`${who} sees that the account is funded`);

  //     // Optionally cause a delay in the participant after they
  //     // receve the signal that the account is funded.
  //     if(delay != 0){
  //       console.log(`${who} begins to wait...`);
  //       await stdlib.wait(delay);
  //     }
  //   },
  //   ready : async () => console.log(`${who} is ready to receive the funds.`),
  //   recvd : async () => console.log(`${who} received the funds.`)
  // });


  const startingBalance = stdlib.parseCurrency(100);

  const [ accAlice, accBob ] =
    await stdlib.newTestAccounts(2, startingBalance);
  console.log('Hello, Alice and Bob!');

  console.log('Launching...');
  const ctcAlice = accAlice.contract(backend);
  const ctcBob = accBob.contract(backend, ctcAlice.getInfo());

  console.log('Starting backends...');
  await Promise.all([
    backend.Alice(ctcAlice, {
      ...stdlib.hasRandom,
      // implement Alice's interact object here

      // Sets the fundObj's values
      getObj: () => {
        console.log('Alice getObj');
        return {goal: 100, maturity: 50}
      },
    }),
    backend.Bob(ctcBob, {
      ...stdlib.hasRandom,
      // implement Bob's interact object here

      // printing out fund object
      showObj: (fundObj) => {
        console.log('Bob showObj');
        console.log({fundObj});
      }
    }),
  ]);

  console.log('Goodbye, Alice and Bob!');
})();
