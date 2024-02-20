## Frame Validator Module

An ERC7579-compatible validator module to validate UserOps using Farcaster Frame signatures.

Compatible with `Entrypoint 0.6` and `Entrypoint 0.7`.

Also compatible with Biconomy V2 accounts.

Built using ModuleKit 0.3.0.

## Usage

### Install dependencies

```shell
pnpm install
```

### Building the module

```shell
forge build
```

### Testing the module

```shell
forge test
```

### Deploying the module

> Note: for security, the module expects the frame URL to be coming from a trusted base URL. For a custom deployment, you can provide your own URL using the `BASE_URL` variable.

Create the `.env` file and provide the environment variables.

```shell
source .env && forge script script/[SCRIPT_NAME].s.sol:[CONTRACT_NAME] --rpc-url $RPC_URL --sender $SENDER_ADDRESS --broadcast
```

## Example

### Polygon Mumbai

```
baseUrl = "https://frame-validator.vercel.app/execute/"
```

- Address: `0x2007dB9DB73AD549439A2ADEe17e74083A275A72` ([explorer](https://mumbai.polygonscan.com/address/0x2007dB9DB73AD549439A2ADEe17e74083A275A72))
- Deployment tx: `0xac8b9a15e98294021c297481789dcb1c69a77364c24411cf8337f47d18709915` ([explorer](https://mumbai.polygonscan.com/tx/0xac8b9a15e98294021c297481789dcb1c69a77364c24411cf8337f47d18709915))
- Installation tx: `0x4a9f4f42bf9f02b6b4a4ee0c1efc664d0a43386036cd966a527af556147e6e60` ([explorer](https://mumbai.polygonscan.com/tx/0x4a9f4f42bf9f02b6b4a4ee0c1efc664d0a43386036cd966a527af556147e6e60))
- Usage tx: `0x3f033d7f14756de0ce822fa69cb3126e224fa0522470b5426ee41f766a7596a7` ([explorer](https://mumbai.polygonscan.com/tx/0x3f033d7f14756de0ce822fa69cb3126e224fa0522470b5426ee41f766a7596a7))

## Design Notes

Uses [`frame-verifier`](https://github.com/wilsoncusack/frame-verifier).

The URL schema is `BASE_URL` + `CHAIN/CALLDATA_HASH`, where `BASE_URL` is the module-defined trusted base URL, `CHAIN` is the chain where the tx will be executed, and `CALLDATA_HASH` is a URL-friendly base64-encoded keccak256 hash of the UserOp calldata.

The frame message data gets passed via UserOp signature.

The best way to understand how to craft the FC frame message and the UserOp payload is to go through the tests.
