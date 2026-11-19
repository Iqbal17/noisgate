import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import solc from "solc";

const input = {
  language: "Solidity",
  sources: {
    "NoisGate.sol": { content: readFileSync("contracts/NoisGate.sol", "utf8") },
    "MockAgentId.sol": { content: readFileSync("contracts/MockAgentId.sol", "utf8") },
  },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    evmVersion: "paris",
    outputSelection: { "*": { "*": ["abi", "evm.bytecode.object", "evm.gasEstimates"] } },
  },
};

const out = JSON.parse(solc.compile(JSON.stringify(input)));
if (out.errors) {
  for (const e of out.errors) {
    console.log(e.severity, e.formattedMessage);
    if (e.severity === "error") process.exitCode = 1;
  }
}
if (process.exitCode) process.exit(1);

mkdirSync("build", { recursive: true });
for (const name of ["NoisGate", "MockAgentId"]) {
  const c = out.contracts[name + ".sol"][name];
  writeFileSync(`build/${name}.json`, JSON.stringify({ abi: c.abi, bytecode: "0x" + c.evm.bytecode.object }, null, 2));
  const bytes = c.evm.bytecode.object.length / 2;
  const creation = c.evm.gasEstimates?.creation;
  console.log(name, "bytecode bytes:", bytes, "creation gas est:", JSON.stringify(creation));
}
console.log("compile OK, solc", solc.version());
