#requires -Version 7
<#
  PUBLICATION SAFETY CHECK

  Runs over everything about to become public. Fails on anything that looks like
  a credential, an internal identifier, or private personal data.

  This is a heuristic and it says so. It recognises credential SHAPES; it cannot
  recognise a secret that reads like prose. It is one of two passes -- the other
  is a human reading every file, which is not automatable and was done.
#>
[CmdletBinding()]
param([string] $Raiz = $PSScriptRoot)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Padrao -> o que ele procura. Nome em ingles porque o relatorio e publico.
$padroes = [ordered]@{
  'AWS access key id'        = 'AKIA[0-9A-Z]{16}'
  'AWS secret-shaped'        = '(?i)aws(.{0,20})?(secret|private)[^\n]{0,4}[=:]\s*[''"][A-Za-z0-9/+=]{40}'
  'GitHub token'             = 'gh[pousr]_[A-Za-z0-9]{36,}'
  'GitHub fine-grained PAT'  = 'github_pat_[A-Za-z0-9_]{60,}'
  'Anthropic key'            = 'sk-ant-[A-Za-z0-9\-_]{20,}'
  'OpenAI key'               = 'sk-[A-Za-z0-9]{32,}'
  'Google API key'           = 'AIza[0-9A-Za-z\-_]{35}'
  'Stripe secret key'        = '(?<![A-Za-z0-9_])[sr]k_(live|test)_[A-Za-z0-9]{16,}'
  'Stripe webhook secret'    = 'whsec_[A-Za-z0-9]{16,}'
  'Langfuse secret key'      = 'sk-lf-[A-Za-z0-9\-]{8,}'
  'Slack token'              = 'xox[baprs]-[A-Za-z0-9-]{10,}'
  'JWT'                      = 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.'
  'private key block'        = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'service_role'             = 'service_role'
  'Supabase project ref'     = '[a-z]{20}\.supabase\.(co|in)'
  'Supabase URL'             = 'https://[a-z0-9-]+\.supabase\.(co|in)'
  'Sentry DSN'               = 'https://[0-9a-f]{16,}@[a-z0-9.]+\.ingest\.[a-z.]*sentry\.io'
  'Cloudflare account id'    = '(?i)account[_-]?id["'':\s]{1,4}[0-9a-f]{32}'
  'S3 bucket (project)'      = 'luckycat-[a-z0-9-]*(backup|db)[a-z0-9-]*'
  'AWS account number'       = '(?<![0-9])\d{12}(?![0-9])'
  'Postgres connection'      = 'postgres(ql)?://[^\s''"]+'
  'internal pages.dev host'  = '[a-z0-9]{8}\.lucky-cat\.pages\.dev'
  'private email'            = '(?i)[a-z0-9._%+-]+@(gmail|hotmail|outlook|yahoo|proton)[.a-z]+'
  'Irish mobile'             = '\+353\s?8[0-9](\s?\d){7,}'
  'Eircode'                  = '(?<![A-Z0-9])[A-Z]\d{2}\s?[A-Z0-9]{4}(?![A-Z0-9])'
  'IBAN'                     = '(?<![A-Z0-9])IE\d{2}[A-Z]{4}\d{14}(?![A-Z0-9])'
  'frozen client name'       = '(?i)seo.?coxinha'
  'op:// secret reference'   = 'op://'
}

# Excecoes deliberadas, cada uma com motivo. Sem isto o check vira ruido e
# alguem o desliga -- que e como um scanner deixa de servir para alguma coisa.
$permitido = @(
  @{ padrao = 'Supabase URL';    valor = 'https://supabase.com'; porque = 'link para a documentacao publica do fornecedor' }
  @{ padrao = 'private email';   valor = 'example@';             porque = 'placeholder em exemplo' }
)

$arquivos = Get-ChildItem -Path $Raiz -Recurse -File |
  Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Name -ne (Split-Path $PSCommandPath -Leaf) } |
  Where-Object { $_.Extension -notin '.jpg', '.jpeg', '.png', '.webp', '.gif', '.ico' }

$achados = New-Object System.Collections.Generic.List[string]
$lidos = 0

foreach ($f in $arquivos) {
  $texto = [System.IO.File]::ReadAllText($f.FullName)
  $lidos++
  $rel = $f.FullName.Substring($Raiz.Length).TrimStart('\', '/')

  foreach ($nome in $padroes.Keys) {
    foreach ($m in [regex]::Matches($texto, $padroes[$nome])) {
      $isento = $permitido | Where-Object { $_.padrao -eq $nome -and $m.Value -like "*$($_.valor)*" }
      if ($isento) { continue }
      # NUNCA imprimir o valor. Um scanner que ecoa o segredo que achou acabou
      # de o copiar para o log, para o terminal e para o transcript.
      $linha = ($texto.Substring(0, $m.Index) -split "`n").Count
      $achados.Add("$rel : linha ${linha} : $nome")
    }
  }
}

Write-Host ''
Write-Host "  arquivos lidos: $lidos   padroes: $($padroes.Count)"
if ($achados.Count -eq 0) {
  Write-Host '  PUBLICATION SAFETY CHECK: PASS' -ForegroundColor Green
  exit 0
}
Write-Host "  PUBLICATION SAFETY CHECK: FAIL ($($achados.Count))" -ForegroundColor Red
foreach ($a in $achados) { Write-Host "    - $a" -ForegroundColor Red }
exit 1
