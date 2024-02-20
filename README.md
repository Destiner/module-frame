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

- Address: `0x5A12815CBcB53D4d2750A1112e0B2C5fBDbe430C` ([explorer](https://mumbai.polygonscan.com/address/0x5A12815CBcB53D4d2750A1112e0B2C5fBDbe430C))
- Deployment tx: `0xe0d8da55e811966988307480d6f06a03fff3d958bcd77f9071102224cf799c3f` ([explorer](https://mumbai.polygonscan.com/tx/0xe0d8da55e811966988307480d6f06a03fff3d958bcd77f9071102224cf799c3f))
- Installation tx: `0xadc2cc9a3270cab9e2bb0139c24a729badc46681bbad48450ae8c25f41757537` ([explorer](https://mumbai.polygonscan.com/tx/0xadc2cc9a3270cab9e2bb0139c24a729badc46681bbad48450ae8c25f41757537))
- Usage tx: `0xa3bd03a0b3272dd0948a3acc95f8c0be453ef6a200b7012a877b749e0c4964ef` ([explorer](https://mumbai.polygonscan.com/tx/0xa3bd03a0b3272dd0948a3acc95f8c0be453ef6a200b7012a877b749e0c4964ef))

## Design Notes

Uses [`frame-verifier`](https://github.com/wilsoncusack/frame-verifier).

The URL schema is `BASE_URL` + `CHAIN/CALLDATA_HASH`, where `BASE_URL` is the module-defined trusted base URL, `CHAIN` is the chain where the tx will be executed, and `CALLDATA_HASH` is a URL-friendly base64-encoded keccak256 hash of the UserOp calldata.

The frame message data gets passed via UserOp signature.

The best way to understand how to craft the FC frame message and the UserOp payload is to go through the tests.
