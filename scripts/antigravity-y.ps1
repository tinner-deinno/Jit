param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $Arguments
)

& antigravity @Arguments -y
exit $LASTEXITCODE
