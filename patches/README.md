# Local build patches

Tape builds pinned upstream revisions with locally maintained patches. Each patch
names its base revision and is applied with `git apply`; incompatible hunks fail
the build.

## Scope and removal conditions

- **`bitcoin-regtest-halving.patch`**
  - **Purpose:** Sets the regtest subsidy halving interval to 210000 blocks,
    matching mainnet. This interval determines the consensus rules for Tape's
    chain.
  - **Removal:** Requires an explicit network/chain compatibility decision, not
    an ordinary dependency upgrade.

- **`regtest-dependencies.patch`**
  - **Purpose:** Locks corrected HTTP and crypto dependencies. Uses
    `indexd 0.9.1`, `leveldown 6.1.1`, BitcoinJS 5 and ZeroMQ 6.
  - **Removal:** When the selected source revision ships equivalent corrected
    dependencies and passes the persistence tests below.

- **`indexd-leveldown6.patch`**
  - **Purpose:** Omits undefined range bounds before passing them to leveldown 6.
    Otherwise confirmed rows can exist on disk but queries return empty after
    restart.
  - **Removal:** When the installed indexd/LevelDB adapter handles missing bounds
    correctly and passes `indexd-leveldown6.test.cjs` without this patch.

- **`electrs-security.patch`**
  - **Purpose:** Locks the corrected dependencies listed below. Storage uses
    schema v1, bincode 1.3.3 and rocksdb 0.21.0.
  - **Removal:** When another revision provides the fixes with compatible data,
    or a separate index migration/reindex has been explicitly planned.

- **`esplora-dependencies.patch`**
  - **Purpose:** Locks corrected HTTP/crypto dependencies and Babel helpers. Its
    postinstall uses `npm ci` for both nested projects so all three projects
    install their locked dependencies.
  - **Removal:** When upstream lockfiles contain equivalent fixes and the
    frontend bundles and serves correctly.

The indexd patch changes queries only, not on-disk records. In indexd 0.9.1, the
wrapper passes missing range bounds as explicit undefined values, which leveldown
6 serializes as keys. See
[the upstream wrapper](https://github.com/bitcoinjs/indexd/blob/master/dbwrapper.js)
and [leveldown's range options](https://github.com/Level/leveldown#dbiteratoroptions).

Esplora uses envify 4, whose parser does not support object-spread syntax. The
compiler, presets and browser-target dependencies must produce JavaScript that
this parser accepts. Check frontend bundling when modifying those dependencies.

## Locked security updates

The npm patches are generated lockfile diffs, including required transitive
dependencies. They cover:

- HTTP: Express, body-parser, qs, proxy-addr and path-to-regexp, including the qs
  denial-of-service and route-parser backtracking fixes. Body-parser 1.20.9
  handles trailing bytes after compressed requests safely (CVE-2026-111181).
- Crypto: base-x, cipher-base, sha.js, elliptic, pbkdf2, tiny-secp256k1 and
  browserify-sign where present, including hashing, key-extraction and signature
  validation fixes. bn.js 4.x consumers use 4.12.5 to avoid CVE-2026-2739.
- Other selected fixes: form-data, cached-path-relative, minimist, Babel traverse
  and Babel's SystemJS transform. Lodash 4.18.1, morgan 1.12.1 and on-headers
  1.1.0 cover their published prototype/template, logging and header-handling
  advisories; minimist 1.2.8 and shell-quote 1.12.0 cover the bundled CLI tools.

The electrs patch locks these corrected versions:

| Crate | Locked version | Advisory |
| --- | --- | --- |
| bytes | 1.11.1 | CVE-2026-25541 |
| crossbeam-channel | 0.5.15 | CVE-2025-4574 |
| time 0.3 | 0.3.47 | CVE-2026-25727 |
| tokio | 1.51.6 | RUSTSEC-2026-0386 |

The time 0.3.47 dependency requires Rust 1.88 or newer. The pinned electrs source
specifies Rust 1.75, so the build uses `cargo +stable` to select the compiler
installed with rustup. The patch covers Cargo.lock; application source and
storage formats are outside its scope.

These patches address selected advisories while maintaining storage compatibility;
they do not guarantee zero scanner findings. Security review must also consider
the pinned application revisions and runtime exposure. Regtest-server uses Tape's
development authorization key and must be restricted to trusted clients.

## Updating the generated patches

Start from clean checkouts of the exact base revisions named in the patch
headers. Generate lockfile changes using Node 22 and review the dependency diff.
Run these commands only when maintaining patches, **not during image builds**:

```sh
# regtest-server
npm update --package-lock-only --ignore-scripts --no-audit --no-fund \
  express body-parser qs proxy-addr path-to-regexp base-x cipher-base sha.js \
  elliptic pbkdf2 tiny-secp256k1 bn.js

# Esplora root
npm update --package-lock-only --ignore-scripts --no-audit --no-fund \
  express body-parser qs proxy-addr path-to-regexp base-x cipher-base sha.js \
  elliptic pbkdf2 browserify-sign @babel/traverse \
  @babel/plugin-transform-modules-systemjs cached-path-relative minimist \
  bn.js lodash morgan on-headers shell-quote

# Esplora client
npm update --package-lock-only --ignore-scripts --no-audit --no-fund \
  qs path-to-regexp base-x cipher-base sha.js elliptic pbkdf2 browserify-sign form-data \
  lodash minimist

# Esplora prerender-server
npm update --package-lock-only --ignore-scripts --no-audit --no-fund body-parser qs form-data

# electrs (requires an installed stable Rust toolchain)
cargo +stable update -p crossbeam-channel --precise 0.5.15
cargo +stable update -p bytes --precise 1.11.1
cargo +stable update -p time@0.3.37 --precise 0.3.47
cargo +stable update -p tokio --precise 1.51.6
```

The Esplora postinstall script must use `npm ci` in both nested projects.
Avoid cosmetic metadata-only churn for unchanged npm packages; do not alter
dependency, peer, platform or install-script metadata to make a diff smaller.
Recheck every patch after changing a source revision or lockfile.

## Validation

The regtest-server build runs `indexd-leveldown6.test.cjs`. It writes a confirmed
row, closes and reopens LevelDB, then checks the range lookup and first-seen
height with a fresh index instance. It fails on unpatched indexd 0.9.1 and passes
with the range-bound patch. It can also be run independently:

```sh
docker run --rm --network none --workdir /root/regtest-server \
  --entrypoint node IMAGE /root/tape-patches/indexd-leveldown6.test.cjs
```

Before accepting an updated image, test each architecture with disposable data:

1. Run the currently deployed image version in an isolated test container. Create
   a wallet, confirmed transaction and both indexes, then stop the test container
   cleanly and copy its test volume.
2. Start the candidate on the copy, with no published ports or external network.
   Check the same chain tip, wallet balances, transaction, regtest UTXO, Esplora
   balance and Electrum history/balance without requesting a reindex.
3. Load Esplora HTML and `/app.js`, create another transaction, mine a block, and
   check that both indexers observe it.
4. Restart the candidate and check that the new balances and transactions persist.
5. Scan the resulting archive and distinguish runtime findings from build tools,
   optional/uncompiled crates and kernel headers. Do not equate a raw count with
   demonstrated reachability, or dismiss remaining findings without assessment.

Never use the active production volume for these tests. Back up production data
consistently and stop the old container cleanly before any eventual deployment.
