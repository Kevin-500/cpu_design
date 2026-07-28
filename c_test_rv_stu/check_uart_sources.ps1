$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot 'c_test'
$files = @(
    '0_uart_test/main.c',
    '1_formatIO_test/main.c',
    '1_formatIO_test/peripheral.c',
    '2_sort_test/main.c',
    '2_sort_test/peripheral.c'
) | ForEach-Object { Join-Path $root $_ }

$todoMatches = Select-String -LiteralPath $files -Pattern 'TODO [1-5]|20XXXXXXXX'
if ($todoMatches) {
    $todoMatches | ForEach-Object { Write-Error "Unfinished source: $($_.Path):$($_.LineNumber)" }
    throw 'UART test sources still contain required TODO placeholders.'
}

foreach ($file in @(
    (Join-Path $root '0_uart_test/main.c'),
    (Join-Path $root '1_formatIO_test/main.c'),
    (Join-Path $root '2_sort_test/main.c')
)) {
    if (-not (Select-String -LiteralPath $file -Pattern '2024311486' -Quiet)) {
        throw "Student ID missing from $file"
    }
}

foreach ($file in @(
    (Join-Path $root '0_uart_test/main.c'),
    (Join-Path $root '1_formatIO_test/peripheral.c'),
    (Join-Path $root '2_sort_test/peripheral.c')
)) {
    if (-not (Select-String -LiteralPath $file -Pattern '\*uart_ctrl_reg\s*=\s*0x3' -Quiet)) {
        throw "UART FIFO clear is missing from $file"
    }
    if (-not (Select-String -LiteralPath $file -Pattern '\*uart_stat_reg\s*&\s*\(1\s*<<\s*3\)' -Quiet)) {
        throw "UART TX-full wait is missing from $file"
    }
    if (-not (Select-String -LiteralPath $file -Pattern '\*uart_stat_reg\s*&\s*1' -Quiet)) {
        throw "UART RX-not-empty wait is missing from $file"
    }
}

Write-Host 'PASS: C_TEST 0~2 UART source checks'
