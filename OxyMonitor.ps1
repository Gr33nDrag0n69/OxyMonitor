<#
.SYNOPSIS
    Monitoring Tool for Oxy Node(s) and Delegate.
    
.DESCRIPTION
    
.PARAMETER ShowMessage
    Output message to screen.

.PARAMETER SendTestEmail
    Send a test e-mail to the configured e-mails ERROR.

.PARAMETER ShowPublicKey
    Internal Helper Tool to find the public key associated to an address.

.PARAMETER TestNet
    Switch that is required to run on TestNet instead of MainNet.

.PARAMETER AsciiBanner
    Show ASCII art banner instead of the basic one line banner.

.EXAMPLE
    .\OxyMonitor.ps1
    
    MainNet normal run built to be executed by a scheduled task.
    
.EXAMPLE
    .\OxyMonitor.ps1 -TestNet
    
    TestNet normal run built to be executed by a scheduled task.
    
.EXAMPLE
    .\OxyMonitor.ps1 -ShowMessage -AsciiBanner
    
    To see on-screen output when script is runned manually. Also showing ASCII banner.
    
.EXAMPLE
    .\OxyMonitor.ps1 -SendTestEmail
    
    To execute the script in e-mail test mode.
    
.NOTES
    Version :   1.0
    Author  :   Gr33nDrag0n
    History :   2017/08/11 - Last Modification
                2017/08/11 - Creation
#>

###########################################################################################################################################
### Parameters
###########################################################################################################################################

[CmdletBinding()]
Param(
    [parameter( Mandatory=$False )]
    [switch] $ShowMessage,
    
    [parameter( Mandatory=$False )]
    [switch] $SendTestEmail,
    
    [parameter( Mandatory=$False )]
    [switch] $ShowPublicKey,
    
    [parameter( Mandatory=$False )]
    [switch] $TestNet,
    
    [parameter( Mandatory=$False )]
    [switch] $AsciiBanner
    
    )

###########################################################################################################################################
### Host Initialization
###########################################################################################################################################

[System.GC]::Collect()
$error.Clear()
if( $ShowMessage ) { Clear-Host }

#######################################################################################################################
# Internal Variables Initialization
#######################################################################################################################

$Script:Config = @{}
$Config.Email = @{}
$Config.Account = @{}
$Config.Nodes = @()
$Config.PublicNodes = @()
$Script:BannerText = 'v1.0 [2017-08-11] by Gr33nDrag0n'

#######################################################################################################################
# Configurable Variables | MANDATORY !!! EDIT THIS SECTION !!!
#######################################################################################################################

### Monitoring ###============================================================================

$Config.MonitoringEnabled = $True
$Config.MonitorNodeBlockHeight = $True
# Warning: You Delegate must have Forging Enabled on 1 of your node to enable this feature.
$Config.MonitorDelegateForgingStatus = $True
# Warning: You must be and "Active Delegate" to enable this feature.
$Config.MonitorDelegateLastForgedBlockAge = $True

### E-Mail ###===============================================================================

$Config.Email.SenderEmail      = ''
$Config.Email.SenderSmtp       = ''
$Config.Email.SendErrorMail    = $True
$Config.Email.ErrorEmailList   = @('')

# Example
#$Config.Email.SenderEmail      = 'oxymonitor@mydomain.com'
#$Config.Email.SenderSmtp       = 'smtp.myISP.com'
#$Config.Email.SendErrorMail    = $True
#$Config.Email.ErrorEmailList   = @('myemail@domain.com','5556781212@myphoneprovider.com')

### Account ###===========================================================================================

$Config.Account.Delegate  = ''
$Config.Account.PublicKey = ''
$Config.Account.Address   = ''

# Example
#$Config.Account.Delegate  = 'gr33ndrag0n_testnet'
#$Config.Account.PublicKey = 'd8275d1078920387c2d102e08a3ff0ef0738304492523b7ec3bf99573e8c65bc'
#$Config.Account.Address   = '6133392596319754840X'

### Node(s) ###=======================================================================================

$Config.Nodes += @{Name='';URI=''}

# Example
#$Config.Nodes += @{Name='test01.oxynode.net';URI='http://test01.oxynode.net:9998/'}

### Public Node(s) ###=======================================================================================

if( $TestNet )
{
  # TestNet (From official TestNet 'config.json' file.)

  $Config.PublicNodes += @{Name='Oxy.io TestNet Seed 1';URI='http://94.176.236.199:9998/'}
  $Config.PublicNodes += @{Name='Oxy.io TestNet Seed 2';URI='http://94.176.236.203:9998/'}
  $Config.PublicNodes += @{Name='Oxy.io TestNet Seed 3';URI='http://94.176.236.206:9998/'}
}
else
{
  # MainNet (From official MainNet 'config.json' file.)

  $Config.PublicNodes += @{Name='Oxy.io MainNet Seed 1';URI='http://45.63.99.16:10000/'}
  $Config.PublicNodes += @{Name='Oxy.io MainNet Seed 2';URI='http://149.202.51.47:10000/'}
  $Config.PublicNodes += @{Name='Oxy.io MainNet Seed 3';URI='http://195.181.244.46:10000/'}
}

###########################################################################################################################################
# FUNCTIONS
###########################################################################################################################################

Function Get-OxyAccountPublicKey {

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $True)]
        [System.String] $URI,

        [parameter(Mandatory = $True)]
        [System.String] $Address
        )
    
    $Private:Output = Invoke-OxyApiCall -Method Get -URI $( $URI+'api/accounts/getPublicKey?address='+$Address )
    if( $Output.success -eq $True ) { $Output.publicKey }
}

###########################################################################################################################################

Function Get-OxySyncStatus {

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $True)]
        [System.String] $URI
        )
    
    $Private:Output = Invoke-OxyApiCall -Method Get -URI $( $URI+'api/loader/status/sync' )
    if( $Output.success -eq $True )
    {
        $Output | Select-Object -Property Syncing, Blocks, Height
    }
}

###########################################################################################################################################

Function Get-OxyBlockList {

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $True)]
        [System.String] $URI,

        [parameter(Mandatory = $False)]
        [System.String] $TotalFee='',

        [parameter(Mandatory = $False)]
        [System.String] $TotalAmount='',

        [parameter(Mandatory = $False)]
        [System.String] $PreviousBlock='',

        [parameter(Mandatory = $False)]
        [System.String] $Height='',

        [parameter(Mandatory = $False)]
        [System.String] $GeneratorPublicKey='',

        [parameter(Mandatory = $False)]
        [System.String] $Limit='',

        [parameter(Mandatory = $False)]
        [System.String] $Offset='',

        [parameter(Mandatory = $False)]
        [System.String] $OrderBy=''
        )

    if( ( $TotalFee -eq '' ) -and ( $TotalAmount -eq '' ) -and ( $PreviousBlock -eq '' ) -and ( $Height -eq '' ) -and ( $GeneratorPublicKey -eq '' ) -and ( $Limit -eq '' ) -and ( $Offset -eq '' ) -and ( $OrderBy -eq '' ) )
    {
        Write-Warning 'Get-OxyBlockList | The usage of at least one parameter is mandatory. Nothing to do.'
    }
    else
    {
        $Private:Query = '?'
        
        if( $TotalFee -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "totalFee=$TotalFee"
        }
        if( $TotalAmount -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "totalAmount=$TotalAmount"
        }
        if( $PreviousBlock -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "previousBlock=$PreviousBlock"
        }
        if( $Height -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "height=$Height"
        }
        if( $GeneratorPublicKey -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "generatorPublicKey=$GeneratorPublicKey"
        }
        if( $Limit -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "limit=$Limit"
        }
        if( $Offset -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "offset=$Offset"
        }
        if( $OrderBy -ne '' )
        {
            if( $Query -ne '?' ) { $Query += '&' }
            $Query += "orderBy=$OrderBy"
        }
        
        $Private:Output = Invoke-OxyApiCall -Method Get -URI $( $URI+'api/blocks'+$Query )
        if( $Output.success -eq $True ) { $Output.blocks }
    }
}

###########################################################################################################################################

Function Get-OxyDelegateForgingStatus {

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $True)]
        [System.String] $URI,
        
        [parameter(Mandatory = $True)]
        [System.String] $PublicKey
        )
    
    $Private:Output = Invoke-OxyApiCall -Method Get -URI $( $URI+'api/delegates/forging/status?publicKey='+$PublicKey )
    if( $Output.success -eq $True ) { $Output.enabled }
}

###########################################################################################################################################

Function Invoke-OxyApiCall {

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $True)]
        [System.String] $URI,
        
        [parameter(Mandatory = $True)]
        [ValidateSet('Get','Post','Put')]
        [System.String] $Method,
        
        [parameter(Mandatory = $False)]
        [System.Collections.Hashtable] $Body = @{}
        )
        
    if( $Method -eq 'Get' )
    {
        Write-Verbose "Invoke-OxyApiCall [$Method] => $URI"
        $Private:WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $URI -Method $Method
    }
    elseif( ( $Method -eq 'Post' ) -or ( $Method -eq 'Put' ) )
    {
        Write-Verbose "Invoke-OxyApiCall [$Method] => $URI"
        $Private:WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $URI -Method $Method -Body $Body
    }
    
    if( ( $WebRequest.StatusCode -eq 200 ) -and ( $WebRequest.StatusDescription -eq 'OK' ) )
    {
        $Private:Result = $WebRequest | ConvertFrom-Json
        if( $Result.success -eq $True ) { $Result }
        else { Write-Warning "Invoke-OxyApiCall | success => false | error => $($Result.error)" }
    }
    else { Write-Warning "Invoke-OxyApiCall | WebRequest returned Status '$($WebRequest.StatusCode) $($WebRequest.StatusDescription)'." }
}

###########################################################################################################################################

Function SendErrorMail {
    Param(
        [parameter( Mandatory=$True, Position=1 )]
        [System.String] $Message
        )
        
    $Private:Subject = 'OxyMonitor'
    Send-MailMessage -SmtpServer $Script:Config.Email.SenderSmtp -From $Script:Config.Email.SenderEmail -To $Script:Config.Email.ErrorEmailList -Subject $Subject -Body $Message -Priority High
}

###########################################################################################################################################

Function GetPublicNodesHighestBlock {

    [CmdletBinding()]
    Param(
        [parameter( Mandatory=$True, Position=1 )]
        $PublicNodeList
        )

    $Private:TopHeight = 0

    ForEach( $Private:PublicNode in $PublicNodeList )
    {
        $Private:SyncStatus = Get-OxySyncStatus -URI $PublicNode.URI
        if( $SyncStatus -ne $NULL )
        {
          if( $TopHeight -lt $SyncStatus.Height ) { $TopHeight = $SyncStatus.Height }
          $Message = $( ' ' + $($PublicNode.Name).PadRight(20,' ') )+'| '+$( $($PublicNode.URI).PadRight(45,' ') )+'| '+$($SyncStatus.Height)
        }
        else
        {
          $Message = $( ' ' + $($PublicNode.Name).PadRight(20,' ') )+'| '+$( $($PublicNode.URI).PadRight(45,' ') )+'| NULL'
        }

        if( $ShowMessage ) { Write-Host $Message }
    }

    $TopHeight
}

###########################################################################################################################################

Function CheckNodeLastBlockLag {

    [CmdletBinding()]
    Param(
        [parameter( Mandatory=$True, Position=1 )]
        [System.String] $URI,
    
        [parameter( Mandatory=$True, Position=2 )]
        [System.Int32] $TopHeight
        )

    $Private:ErrorThresholdInBlocks = 12
    
    $Private:BlockHeightLag = 0
    $Private:Message = ''
    
    $Private:SyncStatus = Get-OxySyncStatus -URI $URI
    if( $SyncStatus -ne $NULL )
    {
        $BlockHeightLag = $TopHeight - $SyncStatus.Height
    
        if( $BlockHeightLag -ge $ErrorThresholdInBlocks ) { $Message = "ERROR: Node Block Lag '$BlockHeightLag' is > $ErrorThresholdInBlocks" }
        else { $Message = "SUCCESS: Node in SYNC. Block Lag is $BlockHeightLag block(s)" }
    }
    else { $Message = "ERROR: Get-OxySyncStatus Result is NULL." }

    $Message
}

###########################################################################################################################################

Function CheckNodeLastBlockAge {

    [CmdletBinding()]
    Param(
        [parameter( Mandatory=$True, Position=1 )]
        [System.String] $URI
        )

    $Private:ErrorThresholdInSeconds = 180
    
    $Private:BlockHeight = 0
    $Private:BlockAgeInSeconds = 0
    $Private:Message = ''
    
    $Private:SyncStatus = Get-OxySyncStatus -URI $URI
    if( $SyncStatus -ne $NULL )
    {
        $BlockHeight = $SyncStatus.Height
        $Private:Block = Get-OxyBlockList -URI $URI -Height $BlockHeight
        if( $Block -ne $NULL )
        {
			if( $TestNet )
			{
				$Private:GenesisTimestamp = Get-Date "5/24/2016 5:00 PM"
			}
			else
			{
				$Private:GenesisTimestamp = Get-Date "5/24/2016 5:00 PM"
			}
            $BlockAgeInSeconds = [math]::Round( $( (Get-date)-([timezone]::CurrentTimeZone.ToLocalTime($GenesisTimestamp.Addseconds($Block.timestamp))) ).TotalSeconds )

            if( $BlockAgeInSeconds -ge $ErrorThresholdInSeconds ) { $Message = "ERROR: Node Block Age is > $ErrorThresholdInSeconds sec. Value: $BlockAgeInSeconds sec." }
            else { $Message = "SUCCESS: Node in SYNC. Block Age is $BlockAgeInSeconds sec." }
        }
        else { $Message = "ERROR: Get-OxyBlockList Result is NULL." }
    }
    else { $Message = "ERROR: Get-OxySyncStatus Result is NULL." }

    $Message
}

###########################################################################################################################################

Function CheckDelegateLastForgedBlockAge {

[CmdletBinding()]
Param(
    [parameter( Mandatory=$True, Position=1 )]
    [System.String] $URI,
    
    [parameter( Mandatory=$True, Position=2 )]
    [System.Collections.Hashtable] $Account
    )

    $Private:ErrorThresholdInMinutes = 101

    $Private:BlockHeight = 0
    $Private:BlockAgeInMinutes = 0
    $Private:Message = ''

    $Private:LastForgedBlock = Get-OxyBlockList -URI $URI -GeneratorPublicKey $Account.PublicKey -Limit 1 -OrderBy 'height:desc'
    if( $LastForgedBlock -ne $NULL )
    {
        $BlockHeight = $LastForgedBlock.Height
		if( $TestNet )
		{
			$Private:GenesisTimestamp = Get-Date "5/24/2016 5:00 PM"
		}
		else
		{
			$Private:GenesisTimestamp = Get-Date "5/24/2016 5:00 PM"
		}
        $BlockAgeInMinutes = [math]::Round( $( (Get-date)-([timezone]::CurrentTimeZone.ToLocalTime($GenesisTimestamp.Addseconds($LastForgedBlock.timestamp))) ).TotalMinutes )
        
        if( $BlockAgeInMinutes -ge $ErrorThresholdInMinutes ) { $Message = "ERROR: Delegate $($Account.Delegate) Last Forged Block Age is > $ErrorThresholdInMinutes minutes. Value: $BlockAgeInMinutes minutes." }
        else { $Message = "SUCCESS: Delegate $($Account.Delegate) Last Forged Block Age is $BlockAgeInMinutes minutes." }
    }
    else { $Message = "ERROR: Get-OxyBlockList Result is NULL. Verify you are part of the 51 currently Active Delegate." }

    $Message
}

###########################################################################################################################################

Function Base64Encode {

    [CmdletBinding()]
    Param(
        [parameter( Mandatory=$True, Position=1 )]
        [System.String] $Text
        )
    
    $( [Convert]::ToBase64String( $( [System.Text.Encoding]::Unicode.GetBytes( $Text ) ) ) )
}

###########################################################################################################################################

Function Base64Decode {
    
    [CmdletBinding()]
    Param(
        [parameter( Mandatory=$True, Position=1 )]
        [System.String] $EncodedText
        )
    
    $( [System.Text.Encoding]::Unicode.GetString( [System.Convert]::FromBase64String( $EncodedText ) ) )
}

###########################################################################################################################################

Function ShowAsciiBanner {

    #$Private:BannerData = Get-Content 'D:\GIT\OxyMonitor\BannerColor.txt'
    #$Private:BannerData64 = Base64Encode -Text $( Get-Content 'D:\GIT\OxyMonitor\BannerColor.txt' | Out-String )
    #$BannerData64 | Out-File 'D:\GIT\OxyMonitor\BannerBase64.txt'

    $Private:BannerData = Base64Decode -EncodedText 'IAAkACwAIAAgACQALAAgACAAIAAgACAALAAiACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAWgAgAFoAIABaACAAWgAgAA0ACgAgAGAAIgBzAHMALgAkAHMAcwAuACAALgBzACcAIgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABaACAAWgAgAFoAIABaACAADQAKACAALgBzAHMAJAAkACQAJAAkACQAJAAkACQAJABzACwAIgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAFoAIAAgACAAIAAgACAAXwBfAF8AXwBaACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAWgBfAF8AIAAgAF8AXwBfAFoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAXwAgAF8AXwAgACAAIAAgACAAIAAgACAAIAAgACAAIAANAAoAIAAkACQAJAAkACQAJAAkACQAJAAkACQAJAAkAGAAJAAkAFMAcwAiACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAWgAgACAAIAAgACAALwAgAF8AXwAgAFwAWgBfACAAIABfAF8AXwBfACAAIABfAF8AWgAvACAAIAB8AC8AIAAgAC8AWgBfAF8AXwAgACAAXwBfAF8AXwAgACAAKABfACkAIAAvAF8AXwBfAF8AXwAgACAAXwBfAF8AXwBfAA0ACgAgACQAJAAkACQAJAAkACQAJAAkACQAJAAkACQAJABvACQAJAAkACAAIAAgACAAIAAgACAALAAiACAAIAAgACAAIABaACAAIAAgACAALwAgAC8AIAAvACAALwBaACAAfAAvAF8ALwAgAC8AIAAvACAAWgAvACAALwB8AF8ALwAgAC8AWgAgAF8AXwAgAFwALwAgAF8AXwAgAFwALwAgAC8AIABfAF8ALwAgAF8AXwAgAFwALwAgAF8AXwBfAC8ADQAKACAAJAAkACQAJAAkACQAJAAkACQAJAAkACQAJAAkACQAJAAkACQAJAAkACQAcwAsACAAIAAsAHMAIgAgACAAIAAgAFoAIAAgACAALwAgAC8AXwAvACAALwBaAD4AIAAgADwALwAgAC8AXwAvACAAWgAvACAALwAgACAALwAgAC8AWgAgAC8AXwAvACAALwAgAC8AIAAvACAALwAgAC8AIAAvAF8ALwAgAC8AXwAvACAALwAgAC8AIAAgACAAIAANAAoAIAAkACQAJAAkACQAIgAkACQAJAAkACQAJAAiACIAIgAiACQAJAAkACQAJAAkACIAJAAkACQAJAAkACwAJwAgACAAWgAgACAAIABcAF8AXwBfAF8ALwBaAF8ALwB8AF8AfABcAF8AXwAsACAAWgAvAF8ALwAgACAALwBfAC8AWgBcAF8AXwBfAF8ALwBfAC8AIAAvAF8ALwBfAC8AXABfAF8ALwBcAF8AXwBfAF8ALwBfAC8AIAAgACAAIAAgAA0ACgAgACQAJAAkACQAJAAkAHMAIgAiACQAJAAkACQAcwBzAHMAcwBzAHMAIgAkACQAJAAkACQAJAAkACQAIgAnACAAIABaACAAIAAgACAAIAAgACAAIABaACAAIAAgACAAIAAvAF8AXwBfAF8ALwBaACAAIAAgACAAIAAgACAAWgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAADQAKACAAJAAkACQAJAAkACcAIAAgACAAIAAgACAAIAAgACAAYAAiACIAIgBzAHMAIgAkACIAJABzACIAIgAnACAAIAAgAFoAIABaACAAWgAgAFoAIAANAAoAIAAkACQAJAAkACQALAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAYAAiACIAIgAiACIAJAAnACAAIAAgACAAWgAgACAAIAAgACAAWgA9AD0APQBCAEEATgBOAEUAUgA9AD0APQBaACAAWgAgAA0ACgAgACQAJAAkACQAJAAkACQAcwAsAC4ALgAuACIAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABaACAAWgAgAFoAIABaACAADQAKACAAJAAkACQAJAAkACQAJAAkACQAJAAkACQAJAAkACQAJAAkACQAIwAjACMAIwBzAC4AJwAgACAAIAAgACAAIAAgAFoAIABaACAAWgAgAFoAIAANAAoADQAKAA=='
	#$BannerData | Out-File 'D:\GIT\OxyMonitor\BannerColor.txt'
    
    $BannerData = $( $BannerData -Replace '===BANNER===',$Script:BannerText ) -Split "`r`n"

    Write-Host ''
    Write-Host ''
    ForEach( $Private:Line in $BannerData ) 
    {
        $Private:Parts = $Line -Split 'Z'
        Write-Host $Parts[0] -ForegroundColor Green -NoNewLine
        Write-Host $Parts[1] -ForegroundColor Yellow -NoNewLine
        Write-Host $Parts[2] -ForegroundColor White -NoNewLine
        Write-Host $Parts[3] -ForegroundColor Yellow -NoNewLine
        Write-Host $Parts[4] -ForegroundColor White
    }
    Write-Host ''
    Write-Host ''
}

###########################################################################################################################################
# MAIN
###########################################################################################################################################

if( $ShowPublicKey )
{
    if( $AsciiBanner ) { ShowAsciiBanner }
    else { Write-Host "`r`n OxyMonitor $BannerText`r`n`r`n" -ForegroundColor Green }
    
    Write-Host " Delegate:  $($Config.Account.Delegate)"
    Write-Host " Address:   $($Config.Account.Address)"
    Write-Host ''
    Write-Host " Public Key:"
    Write-Host ''
    Write-Host ' '$( Get-OxyAccountPublicKey -Address $Config.Account.Address -URI $Config.Nodes[0].URI )
    Write-Host ''
}
elseif( $SendTestEmail )
{
    if( $AsciiBanner ) { ShowAsciiBanner }
    else { Write-Host "`r`n OxyMonitor $BannerText`r`n`r`n" -ForegroundColor Green }
    
    Write-Host ' Sending Test Email(s)...'
    
    if( $Config.Email.SendErrorMail -eq $True ) { SendErrorMail -Message 'OxyMonitor (SendTestEmail)' }
    else { Write-Host ' $Config.Email.SendErrorMail is set to False, Skipping ERROR Email Test.' }
    
    Write-Host " Done`r`n"
}
else
{
    if( $ShowMessage )
    {
        if( $AsciiBanner ) { ShowAsciiBanner }
        else { Write-Host "`r`n OxyMonitor $BannerText`r`n`r`n" -ForegroundColor Green }
    }
    
    $Private:Header = ''
    $Private:Message = ''
    $Private:ErrorMessages = ''
    
    if( $Config.MonitoringEnabled -eq $True )
    {
        if( $Config.MonitorNodeBlockHeight -eq $True )
        {
            # Fetching TopHeight from public nodes
            if( $ShowMessage ) { Write-Host " Checking Public Nodes Top Height`r`n" -ForegroundColor Cyan }
            $Private:TopHeight = GetPublicNodesHighestBlock -PublicNodeList $Config.PublicNodes
            if( $ShowMessage ) { Write-Host "`r`n Public Nodes Top Height : $TopHeight`r`n" -ForegroundColor Cyan }

            # Test individual nodes last block lag

            ForEach( $Private:Node in $Config.Nodes )
            {
                $Private:EmailHeader = 'Node Last Block Lag | '+$($Node.Name)+'|'
                $Private:MessageHeader = $($('Node Last Block Lag').PadRight(35,' ')) + '| ' + $($($Node.Name).PadRight(30,' ')) + '|'
                $Message = CheckNodeLastBlockLag -URI $Node.URI -TopHeight $TopHeight

                if( $Message -like "ERROR:*" ) { $ErrorMessages += "$EmailHeader $Message`r`n`r`n" }

                if( $ShowMessage ) { Write-Host " $MessageHeader $Message" }
            }
            if( $ShowMessage ) { Write-Host '' }

            # Test individual nodes last block age

            ForEach( $Private:Node in $Config.Nodes )
            {
                $Private:EmailHeader = 'Node Last Block Age | '+$($Node.Name)+'|'
                $Private:MessageHeader = $($('Node Last Block Age').PadRight(35,' ')) + '| ' + $($($Node.Name).PadRight(30,' ')) + '|'
                $Message = CheckNodeLastBlockAge -URI $Node.URI

                if( $Message -like "ERROR:*" ) { $ErrorMessages += "$EmailHeader $Message`r`n`r`n" }

                if( $ShowMessage ) { Write-Host " $MessageHeader $Message" }
            }
            if( $ShowMessage ) { Write-Host '' }
        }

        if( $Config.MonitorDelegateLastForgedBlockAge -eq $True )
        {
            if( $Config.Account.PublicKey -eq '' )
            {
                $Config.Account.PublicKey = Get-OxyAccountPublicKey -Address $Config.Account.Address -URI $Config.Nodes[0].URI
            }

            ForEach( $Private:Node in $Config.Nodes )
            {
                $Private:EmailHeader = 'Delegate Last Forged Block Age | '+$($Node.Name)+'|'
                $Private:MessageHeader = $($('Delegate Last Forged Block Age').PadRight(35,' ')) +'| '+$($($Node.Name).PadRight(30,' '))+'|'
                $Message = CheckDelegateLastForgedBlockAge -URI $Node.URI -Account $Config.Account

                if( $Message -like "ERROR:*" ) { $ErrorMessages += "$EmailHeader $Message`r`n`r`n" }

                if( $ShowMessage ) { Write-Host " $MessageHeader $Message" }
            }
            if( $ShowMessage ) { Write-Host '' }
        }

        if( $Config.MonitorDelegateForgingStatus -eq $True )
        {
            if( $Config.Account.PublicKey -eq '' )
            {
                $Config.Account.PublicKey = Get-OxyAccountPublicKey -Address $Config.Account.Address -URI $Config.Nodes[0].URI
            }

            $Header = "Delegate Forging Status |"
            $Private:EmailHeader = 'Delegate Forging Status | '+$($Node.Name)+'|'
            $Private:MessageHeader = $($('Delegate Forging Status').PadRight(67,' ')) +'|'
            $Private:Message = "ERROR: Delegate $($Config.Account.Delegate) is NOT Forging !"

            ForEach( $Private:Node in $Config.Nodes )
            {
                if( $( Get-OxyDelegateForgingStatus -URI $Node.URI -PublicKey $Config.Account.PublicKey ) -eq $True )
                {
                    $Message = "SUCCESS: Delegate $($Config.Account.Delegate) is Forging on $($Node.Name)"
                }
            }

            if( $Message -like "ERROR:*" ) { $ErrorMessages += "$EmailHeader $Message`r`n`r`n" }

            if( $ShowMessage ) { Write-Host " $MessageHeader $Message" }
        }
    }
    else
    {
        if( $ShowMessage ) { Write-Host " Monitoring Disabled, Skipping Section.`r`n" -ForegroundColor Yellow }
    }

    ### E-mail Reporting ###=======================================================================================

    if( $Config.Email.SendErrorMail -eq $True )
    {
        if( $ErrorMessages -ne '' )
        {
            if( $ShowMessage ) { Write-Host "`r`n ERROR Message(s) Detected, Sending E-mail/SMS.`r`n" -ForegroundColor Red }
            SendErrorMail -Message $ErrorMessages
        }
        else
        {
            if( $ShowMessage ) { Write-Host "`r`n No ERROR message(s), Skipping E-mail/SMS.`r`n" -ForegroundColor Green }
        }
    }
    else
    {
        if( $ShowMessage ) { Write-Host '`r`n SendErrorMail = $False, Skipping Email/SMS.`r`n' -ForegroundColor Yellow }
    }
}

############################################################################################################################################################################
### Free Memory
############################################################################################################################################################################

Remove-Variable -Name BannerText -ErrorAction SilentlyContinue
Remove-Variable -Name AsciiBanner -ErrorAction SilentlyContinue
Remove-Variable -Name Config -ErrorAction SilentlyContinue
Remove-Variable -Name ErrorMessages -ErrorAction SilentlyContinue
Remove-Variable -Name foreach -ErrorAction SilentlyContinue
Remove-Variable -Name Header -ErrorAction SilentlyContinue
Remove-Variable -Name Message -ErrorAction SilentlyContinue
Remove-Variable -Name Node -ErrorAction SilentlyContinue
Remove-Variable -Name SendTestEmail -ErrorAction SilentlyContinue
Remove-Variable -Name ShowMessage -ErrorAction SilentlyContinue
Remove-Variable -Name ShowPublicKey -ErrorAction SilentlyContinue
Remove-Variable -Name TopHeight -ErrorAction SilentlyContinue
Remove-Variable -Name EmailHeader -ErrorAction SilentlyContinue
Remove-Variable -Name MessageHeader -ErrorAction SilentlyContinue
Remove-Variable -Name TestNet -ErrorAction SilentlyContinue

$Private:CurrentSessionVariable_List = Get-Variable | Select-Object -ExpandProperty Name

$Private:PowerShellDefaultVariables = @('$','?','^','args','ConfirmPreference','ConsoleFileName','DebugPreference','Error','ErrorActionPreference','ErrorView','ExecutionContext','false','FormatEnumerationLimit','HOME','Host','input',
'MaximumAliasCount','MaximumDriveCount','MaximumErrorCount','MaximumFunctionCount','MaximumHistoryCount','MaximumVariableCount','MyInvocation','NestedPromptLevel','null','OutputEncoding','PID','PROFILE','ProgressPreference',
'PSBoundParameters','PSCmdlet','PSCommandPath','PSCulture','PSDefaultParameterValues','PSEmailServer','PSHOME','PSScriptRoot','PSSessionApplicationName','PSSessionConfigurationName','PSSessionOption','PSUICulture','PSVersionTable',
'PWD','ShellId','StackTrace','true','VerbosePreference','WarningPreference','WhatIfPreference','InformationPreference','PSEdition')

$Private:FreeMemoryVariableFound = $False

ForEach( $Private:CurrentSessionVariable in $CurrentSessionVariable_List )
{
    if( $CurrentSessionVariable -notin $PowerShellDefaultVariables )
    {
        $FreeMemoryVariableFound = $True
        Write-Host "Remove-Variable -Name $CurrentSessionVariable -ErrorAction SilentlyContinue"
    }
}

if( $FreeMemoryVariableFound -eq $True )
{
    Write-Host "Free Memory | Variable(s) Found. If it was created by script execution, edit 'Free Memory' section."
}

Remove-Variable -Name FreeMemoryVariableFound -ErrorAction SilentlyContinue
Remove-Variable -Name PowerShellDefaultVariables -ErrorAction SilentlyContinue
Remove-Variable -Name CurrentSessionVariable_List -ErrorAction SilentlyContinue
Remove-Variable -Name CurrentSessionVariable -ErrorAction SilentlyContinue

[System.GC]::Collect()
