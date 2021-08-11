import amysql
when defined(ChronosAsync):
  import chronos
else:
  import asyncdispatch
import unittest
import net
import times
const database_name = "test"
const port: int = 3306
const host_name = "127.0.0.1"
const user_name = "test_user"
const pass_word = "12345678"
const ssl: bool = false
const verbose: bool = false

proc numberTests(conn: Connection): Future[void] {.async.} =

  discard await conn.selectDatabase(database_name)
  discard await conn.rawQuery("drop table if exists test_dt")
  discard await conn.rawQuery("CREATE TABLE test_dt(col DATE NOT NULL)")

  # Insert values using the binary protocol
  let insrow = await conn.prepare("INSERT INTO test_dt (col) VALUES (?),(?)")
  let d1 = initDate(1,1.Month,2020)
  let d2 = initDate(31,12.Month,2020)
  discard await conn.query(insrow, d1, d2)
  await conn.finalize(insrow)

  # Read them back using the text protocol
  let r1 = await conn.rawQuery("SELECT * FROM test_dt")
  check r1.rows[0][0] == "2020-01-01"
  check r1.rows[1][0] == "2020-12-31"

  # Now read them back using the binary protocol
  let rdtab = await conn.prepare("SELECT * FROM test_dt")
  let r2 = await conn.query(rdtab)

  check r2.rows[0][0] == d1
  check r2.rows[1][0] == d2

  await conn.finalize(rdtab)

  discard await conn.rawQuery("drop table test_dt")

proc runTests(): Future[void] {.async.} =
  let conn = await open(host_name,user_name,pass_word,database_name)
  await conn.numberTests()
  await conn.close()

test "date":
  waitFor(runTests())
