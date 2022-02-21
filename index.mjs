import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);

/*
TODO:
  - set up multiple test cases like workshop-trust-fund did (const rundemo = async (args) =>{} ) to test project meeting its goal and
    not meeting its goal
*/

(async () => {

  // Defines the startingBalance
  const startingBalance = stdlib.parseCurrency(100);

  // Creates Alice and Bob accounts and gives them the starting balance of 100
  const [ accAlice, accBob ] =
    await stdlib.newTestAccounts(2, startingBalance);
  console.log('Hello, Alice and Bob!');

  // Alice deploys contract and Bob attatches to it
  console.log('Launching...');
  const ctcAlice = accAlice.contract(backend);
  const ctcBob = accBob.contract(backend, ctcAlice.getInfo());

  // A helpful function for displaying currency amounts with up to
  // 4 decminal places.
  const fmt = (x) => stdlib.formatCurrency(x, 4);

  // A helpful function for getting the balance of a participant and
  // displaying it with up to 4 decimal places.
  const getBalance = async (who) => fmt(await stdlib.balanceOf(who));

  //get the balance before the game starts for both Alice and Bob
  const beforeAlice = await getBalance(accAlice);
  const beforeBob = await getBalance(accBob);

  console.log('Starting backends...');

  // Waits for the backends to compile
  await Promise.all([
    backend.Alice(ctcAlice, {
      ...stdlib.hasRandom,

      // implement Alice's interact object here

      // Sets the goal of the fund to be 10 currency units
      goal: stdlib.parseCurrency(10),

      // Maturity set to 5000 ms
      maturity: 5000,
    }),
    backend.Bob(ctcBob, {
      ...stdlib.hasRandom,
      // implement Bob's interact object here

      // defines her wager as 5 units of the network token.  This is
      // an example of using a concrete value, rather than a function,
      // in a participant interact interface.
      investment: stdlib.parseCurrency(5),
    }),
  ]);


  /*
  
  Implement fund maturity logic
  - Fund matures after some time (research reach time functions)
  - Check to see if fund reached its goal
  - Yes --> pay out to fund creator
  - No  --> pay back all investors
  - Close fund
  
  */
  
  async function mature(ms) {
    
    // wait 3 seconds
    await new Promise((resolve, reject) => setTimeout(resolve, 3000));    
    

    // TODO: logic to see if fund reached its goal
    /*
    if(current.balance >= goal) {
      pay fund creator address
    }
    else if(current.balance < goal){
      pay to all the addresses that contributed to the fund.
        (gonna have to keep an array of all the investors and how much they invested)
    }
    */
  }
   


  
  
  // After the computation is over, we'll get the balance again
  // and show a message summarizing the effect.
  const afterAlice = await getBalance(accAlice);
  const afterBob = await getBalance(accBob);
  console.log(`Alice went from ${beforeAlice} to ${afterAlice}.`);
  console.log(`Bob went from ${beforeBob} to ${afterBob}.`);

  console.log('Goodbye, Alice and Bob!');
})();
