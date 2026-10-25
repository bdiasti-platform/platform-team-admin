# Equivalente PowerShell do inject_secrets.sh.
# Carrega no Bitwarden cada modelo *.json desta pasta (cria ou atualiza o item).
# Os arquivos *.json_example não entram no laço. Não precisa de jq.

# Carrega o ../.env nas variáveis de ambiente (equivale ao "set -o allexport; source")
$envFile = Join-Path $PSScriptRoot '..\.env'
$envNames = @()
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
        $name, $value = $line -split '=', 2
        Set-Item "env:$($name.Trim())" $value.Trim()
        $envNames += $name.Trim()
    }
}

try {
    # "bw login" falha se já houver login; por isso só loga quando necessário
    $status = (bw status | ConvertFrom-Json).status
    if ($status -eq 'unauthenticated') {
        bw login --apikey
        if ($LASTEXITCODE -ne 0) { throw 'Falha no bw login --apikey. Confira BW_CLIENTID e BW_CLIENTSECRET no .env.' }
    }

    $session = bw unlock --passwordenv BW_PASSWORD --raw
    if ($LASTEXITCODE -ne 0 -or -not $session) { throw 'Falha no bw unlock. Confira BW_PASSWORD no .env.' }

    # Atualiza o cache local antes de procurar/editar, para não editar uma versão antiga do item
    bw sync --session $session | Out-Null

    # Filtra pela extensão exata para não pegar os *.json_example
    $jsonFiles = Get-ChildItem -Path $PSScriptRoot -File | Where-Object { $_.Extension -eq '.json' }

    foreach ($jsonFile in $jsonFiles) {
        Write-Host "Processing: $($jsonFile.Name)"

        $json = Get-Content $jsonFile.FullName -Raw -Encoding UTF8
        $itemName = ($json | ConvertFrom-Json).name

        # Mesmo resultado do "bw encode": o JSON em base64
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))

        # Try to get an existing item, if it exists, update, otherwise
        # create new. "bw get item <nome>" faz busca aproximada ("Pulumi Secrets"
        # casa com "GitHub Secrets"), por isso filtra pelo nome exato.
        # Guarda numa variável antes de filtrar: no PowerShell 5.1 o ConvertFrom-Json
        # passa o array inteiro como um objeto só no pipe, e o filtro não funciona
        $searchResults = bw list items --search $itemName --session $session | ConvertFrom-Json
        $found = @($searchResults | Where-Object { $_.name -ceq $itemName })
        if ($found.Count -gt 1) { throw "Há $($found.Count) itens chamados '$itemName' no cofre. Remova os duplicados." }
        if ($found.Count -eq 1) {
            Write-Host "Item '$itemName' exists, updating..."
            $itemId = $found[0].id
            $result = bw edit item $itemId $encoded --session $session 2>&1
        }
        else {
            Write-Host "Item '$itemName' does not exist, creating..."
            $result = bw create item $encoded --session $session 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            $bwError = ($result | Where-Object { "$_" -notmatch 'punycode|trace-deprecation' }) -join ' '
            throw "Falha ao gravar o item '$itemName' no Bitwarden: $bwError"
        }
    }

    bw sync --session $session
}
finally {
    bw lock | Out-Null
    # Não deixa os segredos do .env na sessão do PowerShell depois que o script termina
    foreach ($name in $envNames) { Remove-Item "env:$name" -ErrorAction SilentlyContinue }
}
