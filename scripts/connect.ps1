param(
    [string]$PrimaryHost = "mysql-node1",
    [string]$SecondaryHost = "mysql-node2",
    [string]$User = "appuser",
    [string]$Password = "appsecret"
)

function Test-MySql($Host) {
    & mysql --connect-timeout=5 -h $Host -u $User -p$Password -e "SELECT 1" >$null 2>&1
    return $LASTEXITCODE -eq 0
}

if (-not (Test-MySql $PrimaryHost)) {
    Test-MySql $SecondaryHost | Out-Null
}
