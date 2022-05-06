import {loadStdlib} from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);


const GOAL = stdlib.parseCurrency(10);

const startingBalance = stdlib.parseCurrency(100);  

const deadline = 50;
const FUNDGOAL = GOAL;

// Helper function for holding the balance of a participant
const getBalance = async (who) => stdlib.parseCurrency(await stdlib.balanceOf(who), 4,);

// Prints to console the amount that the funder intends to pay
console.log(`Fund goal is set to ${GOAL}.`);

// Creates receiver and funder test accounts with the starting balance
const receiver = await stdlib.newTestAccount(startingBalance);

console.log("Creating receiver");
// Receiver deploys the contract
const ctcReceiver = receiver.contract(backend);


console.log("Creating fund");

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

console.log("Making test accounts");
const users = await stdlib.newTestAccounts(2, startingBalance);

const ctcWho = (whoi) => users[whoi].contract(backend, ctcReceiver.getInfo());

const donate = async (whoi, amount) => {
  const who = users[whoi];
  // Attatches the funder to the backend that the receiver deployed.
  const ctc = ctcWho(whoi);
  // Calls the donateToFund function from backend.
  console.log(stdlib.formatAddress(who), `donated ${amount} to fund`);
  await ctc.apis.Funder.donateToFund(amount);
};
const timesup = async () => {
  console.log('I think time is up');
  await ctcReceiver.apis.Bystander.timesUp();
};
const timesuppayback = async () => {
  console.log('I think time is up');
  const success = await ctcReceiver.apis.Bystander.timesUpPayBack();
  console.log(`Finished timesuppayback function? ${success}`);
};
const printfundbal = async () => {
  const fundbal = await ctcReceiver.apis.Bystander.printFundBal();
  console.log(`Fund balance: ${fundbal}`);
};
const printgoal = async () => {
  const goal = await ctcReceiver.apis.Bystander.printGoal();
  console.log(`Goal: ${goal}`);
};
const printbalance = async () => {
  const balance = await ctcReceiver.apis.Bystander.printBalance();
  console.log(`Contract balance: ${balance}`);
};
const printbalanceagain = async () => {
  const balance = await ctcReceiver.apis.Bystander.printBalanceAgain();
  console.log(`Contract balance: ${balance}`);
};
const printoutcome = async () => {
  const outcome = await ctcReceiver.apis.Bystander.printOutcome();
  console.log(`Fund ${outcome? `did` : `did not`} meet its goal.`);
};
const paymeback = async (whoi) => {
  const who = users[whoi];
  // Attatches the funder to the backend that the receiver deployed.
  const ctc = ctcWho(whoi);
  // Calls the donateToFund function from backend.
  console.log(stdlib.formatAddress(who), `Got their funds back`);
  await ctc.apis.Funder.payMeBack();
};

// Test account user 0 donates 10 currency to fund.
await donate(0, stdlib.parseCurrency(5));
// Test account user 1 donates 1 currency to fund. 
await donate(1, stdlib.parseCurrency(3));

// Waits for the fund to mature
console.log(`Waiting for the fund to reach the deadline.`);
await stdlib.wait(deadline);


await timesup();
await printoutcome();
await printfundbal();
await printbalance();
await printgoal();

await paymeback(0);
await paymeback(1);

console.log(`Waiting for the end of the payBack period.`);
await stdlib.wait(deadline*2);



await printbalanceagain();


// Prints the final balances of all accounts
for ( const who of [ receiver, ...users ]) {
  console.warn(stdlib.formatAddress(who), 'has',
  stdlib.formatCurrency(await stdlib.balanceOf(who)));
}

console.log(`\n`);

