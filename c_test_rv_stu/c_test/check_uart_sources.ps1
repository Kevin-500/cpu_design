$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$files = @(
    (Join-Path $root '0_uart_test/main.c'),
    (Join-Path $root '1_formatIO_test/main.c'),
    (Join-Path $root '1_formatIO_test/peripheral.c'),
    (Join-Path $root '2_sort_test/main.c'),
    (Join-Path $root '2_sort_test/peripheral.c')
)

foreach ($file in $files) {
    $text = Get-Content -Raw -LiteralPath $file
    if ($text -match 'TODO' -or $text -match '20XXXXXXXX') {
        throw "Unfinished C_TEST source: $file"
    }
}

$test0 = Get-Content -Raw -LiteralPath (Join-Path $root '0_uart_test/main.c')
if ($test0 -notmatch '\*uart_ctrl_reg\s*=\s*0x3;') { throw 'Test 0 does not clear UART FIFOs.' }
if ($test0 -notmatch '\*uart_stat_reg\s*&\s*\(1\s*<<\s*3\)') { throw 'Test 0 does not wait for TX availability.' }
if ($test0 -notmatch '!\s*\(\s*\*uart_stat_reg\s*&\s*1\s*\)') { throw 'Test 0 does not wait for RX data.' }

foreach ($name in @('1_formatIO_test', '2_sort_test')) {
    $text = Get-Content -Raw -LiteralPath (Join-Path $root "$name/peripheral.c")
    if ($text -notmatch '\*uart_ctrl_reg\s*=\s*0x3;') { throw "$name does not clear UART FIFOs." }
    if ($text -notmatch 'rx_buf_cnt\s*=\s*0;') { throw "$name does not reset rx_buf_cnt." }
    if ($text -notmatch 'rx_buf_ptr\s*=\s*0;') { throw "$name does not reset rx_buf_ptr." }
    if ($text -notmatch '\*uart_stat_reg\s*&\s*\(1\s*<<\s*3\)') { throw "$name does not wait for TX availability." }
    if ($text -notmatch '!\s*\(\s*\*uart_stat_reg\s*&\s*1\s*\)') { throw "$name does not wait for RX data." }
}

Write-Host 'PASS: C_TEST UART source contract'
