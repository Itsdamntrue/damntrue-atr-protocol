const { ethers } = require("ethers");
require("dotenv").config();

async function runReporter() {
  const provider = new ethers.JsonRpcProvider(process.env.FLOP_RPC_URL || "http://127.0.0.1:8545");
  const wallet = new ethers.Wallet(process.env.REPORTER_PRIVATE_KEY, provider);

  const contractAddress = process.env.ATR_CONTRACT_ADDRESS;
  const chainId = (await provider.getNetwork()).chainId;

  const domain = {
    name: "DamnTrueATR",
    version: "1",
    chainId: chainId,
    verifyingContract: contractAddress
  };

  const types = {
    BatchMetrics: [
      { name: "metrics", type: "Metric[]" },
      { name: "nonce", type: "uint256" }
    ],
    Metric: [
      { name: "agent", type: "address" },
      { name: "success", type: "bool" },
      { name: "latencyMs", type: "uint64" },
      { name: "volume", type: "uint256" },
      { name: "disputeLost", type: "bool" }
    ]
  };

  const metricsBatch = [
    {
      agent: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      success: true,
      latencyMs: 120,
      volume: ethers.parseUnits("50", 18),
      disputeLost: false
    }
  ];

  const atrAbi = [
    "function reporterNonces(address) view returns (uint256)",
    "function submitBatchMetrics(tuple(address agent, bool success, uint64 latencyMs, uint256 volume, bool disputeLost)[] metrics, bytes signature) external"
  ];

  const contract = new ethers.Contract(contractAddress, atrAbi, wallet);
  const nonce = await contract.reporterNonces(wallet.address);

  const value = {
    metrics: metricsBatch,
    nonce: nonce
  };

  console.log("Signing EIP-712 metrics payload...");
  const signature = await wallet.signTypedData(domain, types, value);

  console.log("Submitting batch to Flop Network...");
  const tx = await contract.submitBatchMetrics(metricsBatch, signature);
  await tx.wait();
  console.log(`Batch confirmed! Tx Hash: ${tx.hash}`);
}

runReporter().catch(console.error);
