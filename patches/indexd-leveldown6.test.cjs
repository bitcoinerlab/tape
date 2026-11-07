// Run from the installed regtest-server directory.
const assert = require('node:assert/strict')
const crypto = require('node:crypto')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { promisify } = require('node:util')

const leveldown = require(path.join(process.cwd(), 'node_modules/leveldown'))
const Indexd = require(path.join(process.cwd(), 'node_modules/indexd'))

async function main () {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'tape-indexd-'))
  const db = leveldown(directory)
  const script = Buffer.from('0014' + '11'.repeat(20), 'hex')
  const scId = crypto.createHash('sha256').update(script).digest('hex')
  const txId = '22'.repeat(32)

  try {
    await promisify(db.open.bind(db))({})
    const index = new Indexd(db, () => {})
    const batch = index.db.atomic()
    index.indexes.script.connect(batch, {
      blockId: '33'.repeat(32),
      height: 1,
      transactions: [{ txId, ins: [{ coinbase: '00' }], outs: [{ vout: 0, script, value: 125000000 }] }]
    })
    await promisify(batch.write.bind(batch))()
    await promisify(db.close.bind(db))()

    // A fresh index instance must find the on-disk row, without a mempool cache.
    await promisify(db.open.bind(db))({})
    const reopened = new Indexd(db, () => {})
    const rows = await promisify(reopened.txosByScriptRange.bind(reopened))(
      { scId, heightRange: [0, 0xffffffff], mempool: false }, 440
    )
    assert.equal(rows.length, 1, 'confirmed row must remain readable after reopening')
    assert.equal(rows[0].txId, txId)
    assert.equal(rows[0].height, 1)
    assert.equal(rows[0].value, 125000000)
    assert.equal(await promisify(reopened.firstSeenScriptId.bind(reopened))(scId), 1)
    console.log('PASS: indexd reads persisted range results after reopening LevelDB')
  } finally {
    if (db.status === 'open') await promisify(db.close.bind(db))()
    fs.rmSync(directory, { recursive: true, force: true })
  }
}

main().catch(error => {
  console.error(error)
  process.exitCode = 1
})
