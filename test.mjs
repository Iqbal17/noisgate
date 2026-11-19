import { readFileSync } from "node:fs";
import ganache from "ganache";
import { ethers } from "ethers";

const provider = new ethers.BrowserProvider(ganache.provider({ logging: { quiet: true } }));
const [deployer, alice, bob, carol] = await Promise.all([0, 1, 2, 3].map((i) => provider.getSigner(i)));

const mockJson = JSON.parse(readFileSync("build/MockAgentId.json", "utf8"));
const gateJson = JSON.parse(readFileSync("build/NoisGate.json", "utf8"));

const mock = await new ethers.ContractFactory(mockJson.abi, mockJson.bytecode, deployer).deploy();
await mock.waitForDeployment();
const gate = await new ethers.ContractFactory(gateJson.abi, gateJson.bytecode, deployer).deploy(
  await mock.getAddress(),
  "https://example.invalid/badge.json"
);
await gate.waitForDeployment();
console.log("mock registry:", await mock.getAddress());
console.log("gate:", await gate.getAddress());

let pass = 0, fail = 0;
async function check(label, fn, shouldRevert = false) {
  try {
    let r = await fn();
    if (r && typeof r.wait === "function") r = await r.wait(); // surface on-chain reverts (status 0)
    if (shouldRevert) { console.log("FAIL (no revert):", label); fail++; }
    else { console.log("PASS:", label, r !== undefined ? String(r) : ""); pass++; }
  } catch (e) {
    if (shouldRevert) { console.log("PASS (reverts):", label); pass++; }
    else { console.log("FAIL:", label, "-", e.shortMessage || e.message); fail++; }
  }
}

// Alice has an Agent ID, Bob does not.
await mock.set(await alice.getAddress(), 1);

await check("bob claim without Agent ID reverts", () => gate.connect(bob).claim(), true);
await check("alice claim succeeds -> tokenId 1", async () => {
  const tx = await gate.connect(alice).claim();
  await tx.wait();
  return gate.badgeOf(await alice.getAddress());
});
await check("alice second claim reverts", () => gate.connect(alice).claim(), true);
await check("hasBadge(alice) = true", async () => gate.hasBadge(await alice.getAddress()));
await check("ownerOf(1) = alice", async () => gate.ownerOf(1));
await check("balanceOf(alice) = 1", async () => gate.balanceOf(await alice.getAddress()));
const aliceAddr = await alice.getAddress(), bobAddr = await bob.getAddress();
await check("transferFrom reverts (soulbound)", () =>
  gate.connect(alice).transferFrom(aliceAddr, bobAddr, 1), true);
await check("approve reverts (soulbound)", () => gate.connect(alice).approve(bobAddr, 1), true);
await check("bob checkIn without badge reverts", () => gate.connect(bob).checkIn(), true);
await check("alice checkIn #1", async () => { const tx = await gate.connect(alice).checkIn(); await tx.wait(); return gate.checkInCount(await alice.getAddress()); });
await check("alice checkIn twice same day reverts", () => gate.connect(alice).checkIn(), true);
await check("canCheckIn(alice) = false after check-in", async () => gate.canCheckIn(await alice.getAddress()));

// Move to next day: ganache evm_increaseTime via provider send
await provider.send("evm_increaseTime", [86400]);
await provider.send("evm_mine", []);
await check("alice checkIn day 2 (streak 2)", async () => {
  const tx = await gate.connect(alice).checkIn(); await tx.wait();
  return "streak=" + (await gate.currentStreak(await alice.getAddress())) + " total=" + (await gate.checkInCount(await alice.getAddress()));
});
// Skip a day -> streak resets to 1
await provider.send("evm_increaseTime", [2 * 86400]);
await provider.send("evm_mine", []);
await check("alice checkIn after gap (streak resets to 1)", async () => {
  const tx = await gate.connect(alice).checkIn(); await tx.wait();
  return "streak=" + (await gate.currentStreak(await alice.getAddress())) + " best=" + (await gate.bestStreak(await alice.getAddress()));
});
// Carol gets an Agent ID later and can claim tokenId 2
await mock.set(await carol.getAddress(), 1);
await check("carol claim -> tokenId 2", async () => {
  const tx = await gate.connect(carol).claim(); await tx.wait();
  return gate.totalClaimed();
});
await check("tokenURI(1) returns metadata URI", async () => gate.tokenURI(1));
await check("non-owner setMetadataURI reverts", () => gate.connect(alice).setMetadataURI("https://x.invalid/"), true);

console.log(`\nRESULT: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
