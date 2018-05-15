Get-Module -Name PowerShellGet -ListAvailable | Select-Object -Property Name,Version,Path

set-executionpolicy remotesigned

Install-Module PowerShellGet -Force

Install-Module -Name AzureRM -AllowClobber

Get-Module AzureRM -ListAvailable | Select-Object -Property Name,Version,Path

login-azurermaccount

# Variables for common values
$resourceGroup = "AzureAutoArch"
$storageaccount="ArchStore"
$storagecontainer="VMCustomScript"

$location = "Westus"
# The logical server name: Use a random value or replace with your own value (do not capitalize)
$servername = "NotesApp-Server"
# Set an admin login and password for your database
# The login information for the server
$adminlogin = "devops"
$password = "Globe@2020"
# The ip address range that you want to allow to access your server - change as appropriate
$startip = "0.0.0.0"
$endip = "0.0.0.0"
# The database name
$availabilitySetName1="APP-avail-set"
$availabilitySetName2="API-avail-set"
$databasename = "NotesDatabase"
$RedisCacheName="NotesRedisCache"
$ServiceBusname="NotesServiceBus"
$servicebusQueue="NotesReminder"
$servicebusrule="NotesReminderPolicy"
$vmName1 = "notesappvm"
$vmName2 = "notesapivm"
$namespace="notesservicebus"
$DomainNameLabel="notesapploadbalancer"

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a resource group
New-AzureRmResourceGroup -Name $resourceGroup -Location $location

#storage account

New-AzureRmStorageAccount -Location $location -Name $storageaccount -ResourceGroupName $resourceGroup -SkuName Standard_GRS 
$StorageAccountKey=Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup  -name $storageaccount

$ctx = New-AzureStorageContext -StorageAccountName $storageaccount  -StorageAccountKey $StorageAccountKey.value[0]

New-AzureStorageContainer -Name $storagecontainer -Context $ctx -Permission Blob


# Create a subnet configuration
$subnetConfig1= New-AzureRmVirtualNetworkSubnetConfig -Name publicSubnet -AddressPrefix 192.168.0.0/24 -ServiceEndpoint Microsoft.sql
###$subnetConfig2= New-AzureRmVirtualNetworkSubnetConfig -Name privateSubnet1 -AddressPrefix 192.168.1.0/24
###$subnetConfig3= New-AzureRmVirtualNetworkSubnetConfig -Name privateSubnet2 -AddressPrefix 192.168.2.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name BridgelabzVnet -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig1

# Create a public IP address and specify a DNS name
#$appip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
 # -Name "appip$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4

#$apiip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
#  -Name "apiip$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4

#Create the availability set

$appset=New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Name $availabilitySetName1 -Location $location -Sku Aligned -PlatformFaultDomainCount 3 -PlatformUpdateDomainCount 3
$apiset=New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroup -Name $availabilitySetName2 -Location $location -Sku Aligned -PlatformFaultDomainCount 3 -PlatformUpdateDomainCount 3

#Creating a public load balancer 

$APPLBIP = New-AzureRmPublicIpAddress -Name applbip -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Static -DomainNameLabel $DomainNameLabel
$appfrontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name APP-LB-Frontend -PublicIpAddress $APPLBIP
$apppool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name APP-LB-backend
$appinboundNATRule= New-AzureRmLoadBalancerInboundNatRuleConfig -Name APPRDP -FrontendIpConfiguration $appfrontendIP -Protocol TCP -FrontendPort 3441 -BackendPort 3389
$apphealthProbe = New-AzureRmLoadBalancerProbeConfig -Name APPHealthProbe -RequestPath / -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2

$applbrule = New-AzureRmLoadBalancerRuleConfig -Name APPHTTP -FrontendIpConfiguration $appfrontendIP -BackendAddressPool  $appPool -Probe $apphealthProbe -Protocol Tcp -FrontendPort 80 -BackendPort 80

$APPLB = New-AzureRmLoadBalancer -ResourceGroupName $resourceGroup -Name applb -Location $location -FrontendIpConfiguration $appfrontendIP -InboundNatRule $appinboundNATRule -LoadBalancingRule $applbrule -BackendAddressPool $appPool -Probe $apphealthProbe
#Creating a private load balancer

$apifrontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name API-LB-Frontend -PrivateIpAddress 192.168.0.110 -SubnetId $vnet.subnets[0].Id
$apipool= New-AzureRmLoadBalancerBackendAddressPoolConfig -Name API-LB-backend
$apiinboundNATRule= New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP1" -FrontendIpConfiguration $apifrontendIP -Protocol TCP -FrontendPort 3442 -BackendPort 3389

$apihealthProbe= New-AzureRmLoadBalancerProbeConfig -Name "APIHealthProbe" -RequestPath / -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2

$apilbrule = New-AzureRmLoadBalancerRuleConfig -Name "APIHTTP" -FrontendIpConfiguration $apifrontendIP -BackendAddressPool $apiPool -Probe $apihealthProbe -Protocol Tcp -FrontendPort 80 -BackendPort 80
$APILB = New-AzureRmLoadBalancer -ResourceGroupName $resourceGroup -Name apilb -Location $location -FrontendIpConfiguration $apifrontendIP -InboundNatRule $apiinboundNATRule -LoadBalancingRule $apilbrule -BackendAddressPool $apiPool -Probe $apihealthProbe

# Create an inbound network security group rule for port 3389,80,1433

$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" `
-Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
-SourceAddressPrefix Internet -SourcePortRange * `
-DestinationAddressPrefix * -DestinationPortRange 3389

$rule2 = New-AzureRmNetworkSecurityRuleConfig -Name web-rule -Description "Allow HTTP" `
-Access Allow -Protocol Tcp -Direction Inbound -Priority 101 `
-SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * `
-DestinationPortRange 80

# Create a network security group
$nsgapp = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name appnsg -SecurityRules $rule1,$rule2

$nsgapi = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name apinsg -SecurityRules $rule1,$rule2

# Create a virtual network card and associate with public IP address and NSG
$nic1=New-AzureRmNetworkInterface -ResourceGroupName $resourceGroup -Location $location -Name appNic -Subnet $vnet.Subnets[0] -NetworkSecurityGroup $nsgapp -LoadBalancerBackendAddressPool $apppool -LoadBalancerInboundNatRule $appinboundNATRule

$nic2 = New-AzureRmNetworkInterface -Name apiNic -ResourceGroupName $resourceGroup -Location $location  `
  -Subnet $vnet.Subnets[0] -NetworkSecurityGroup $nsgapi -LoadBalancerBackendAddressPool $apipool -LoadBalancerInboundNatRule $apiinboundNATRule 

# Create a virtual machine configuration
$appvmConfig = New-AzureRmVMConfig -VMName $vmName1 -VMSize Standard_B2s -AvailabilitySetId $appset.Id | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName1 -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Add-AzureRmVMNetworkInterface -Id $nic1.Id

$apivmConfig = New-AzureRmVMConfig -VMName $vmName2 -VMSize Standard_B2s -AvailabilitySetId $apiset.Id| `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName2 -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Add-AzureRmVMNetworkInterface -Id $nic2.Id

# Create a virtual machine
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $appvmConfig 
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $apivmConfig 

#Add port 1433 to NSG and VM
$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name apinsg
Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
-Name DBRule `
-Description "Allow DB " `
-Access Allow `
-Protocol Tcp `
-Direction Inbound `
-Priority 105 `
-SourceAddressPrefix * `
-SourcePortRange * `
-DestinationAddressPrefix * `
-DestinationPortRange 1433

Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg


#SQL Server and Database
New-AzureRmSqlServer -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -Location $location `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminlogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))


New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -FirewallRuleName "AllowSome" -StartIpAddress $startip -EndIpAddress $endip

New-AzureRmSqlDatabase  -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -DatabaseName $databasename

$virtualNetworkRule = New-AzureRmSqlServerVirtualNetworkRule -VirtualNetworkRuleName DBFirewallRule -ResourceGroupName $resourceGroup -ServerName $servername  -VirtualNetworkSubnetId  $vnet.subnets[0].Id

#Service bus

New-AzureRmServiceBusNamespace -Location $location -Name $ServiceBusname -ResourceGroupName $resourceGroup -SkuName Basic 

$CurrentNamespace = Get-AzureRMServiceBusNamespace -ResourceGroup $resourceGroup -NamespaceName $ServiceBusname

New-AzureRmServiceBusQueue -Name $servicebusQueue -Namespace $ServiceBusname -ResourceGroupName $resourceGroup -MaxSizeInMegabytes 1024

New-AzureRmServiceBusAuthorizationRule -Name $servicebusrule -Namespace $ServiceBusname -Queue $servicebusQueue -ResourceGroupName $resourceGroup -Rights Send,listen,manage

# Redis Cache
New-AzureRmRedisCache -ResourceGroupName $resourceGroup -Name $RedisCacheName -Location $location -Sku Basic -Size 250MB



# Environment variable

'Set-WebBinding -Name "Default Web Site" -BindingInformation "*:80:" -PropertyName Port -Value 1234' | Out-File "C:\Windows\System32\DefaultWebSite.txt"

"Add-WindowsFeature Web-Server -IncludeManagementTools -includeallsubfeature" | Out-File "C:\Windows\System32\IISServer.txt"
Get-Content server.txt,modifyport.txt | Set-Content webserver.txt

# DNS name of Frontend loadbalancer     

"$"+"dns="+"'"+"http://"+$DomainNameLabel+"."+$location+".cloudapp.azure.com"+"'" | Out-File "C:\Windows\System32\DNSName.txt"

# RedisCache Connection String                      

(Get-AzureRmRedisCacheKey -Name $RedisCacheName).PrimaryKey | Out-File "C:\Windows\System32\RedisKey.txt"
$rediskey=Get-Content "C:\Windows\System32\RedisKey.txt"

'$'+"rediskey="+"'"+$RedisCacheName+".redis.cache.windows.net:6380,password="+$rediskey+",ssl=True,abortConnect=False"+ "'" | Out-File "C:\Windows\System32\RedisConnection.txt"

# Service Bus Key, Namespace                 

(Get-AzureRmServiceBusKey -ResourceGroup $resourcegroup -Namespace $ServiceBusname -Queue $servicebusQueue -Name $servicebusrule).PrimaryConnectionString | Out-File "C:\Windows\System32\buskey.txt"
$buskey=Get-Content "C:\Windows\System32\GetServiceBusKey.txt"
'$'+"servicebuskey="+"'"+$buskey+"'" | Out-File "C:\Windows\System32\ServiceBusKey.txt"
'$'+"queuename="+"'"+$servicebusQueue+"'" | Out-File "C:\Windows\System32\ServiceBusQueue.txt"

# Blob Storage Account Key              

'$'+"BlobAccount="+"'"+$storageaccount+"'" | Out-File "C:\Windows\System32\BlobAccount.txt"
'$'+"BlobContainer="+"'"+$storagecontainer+"'" | Out-File "C:\Windows\System32\BlobContainer.txt"
(Get-AzureRmStorageAccountKey -Name $storageaccount -ResourceGroupName $resourcegroup).Value[0] | Out-File "C:\Windows\System32\BlobStorageKey.txt"
$BlobKey=Get-Content "C:\Windows\System32\BlobStorageKey.txt"
'$'+"BlobKey="+"'"+$BlobKey+"'" | Out-File "C:\Windows\System32\BlobKey.txt"
'$'+"StoragePath="+"'"+"https://"+$storageaccount+".blob.core.windows.net/"+"'" | Out-File "C:\Windows\System32\BlobStoragePath.txt"

# Database Connection String             

'$'+"DBKey='Server=tcp:"+$servername+".database.windows.net,1433;Initial Catalog="+$databasename+";Persist Security Info=False;
User ID="+$adminlogin+";Password="+$password+";MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" + "'" | Out-File "C:\Windows\System32\DBKey.txt"

Get-Content webserver.txt,rediskeyconnectionstring.txt,servicebuskey.txt,servicebusqueue.txt,BlobContainer.txt,BlobAccount.txt,BlobKey.txt,StoragePath.txt,DBKey.txt,dnsname.txt,EnvironmentVariable.ps1 | Set-Content AppFINAL.ps1
Get-Content webserver.txt,rediskeyconnectionstring.txt,servicebuskey.txt,servicebusqueue.txt,BlobContainer.txt,BlobAccount.txt,BlobKey.txt,StoragePath.txt,DBKey.txt,dnsname.txt,EnvironmentVariable.ps1 | Set-Content ApiFINAL.ps1

#Uploading Custom Script To Blob Storage

$localFileDirectory = "C:\Windows\System32\"
$BlobName1 = "NotesAPPVM.ps1" 
$BlobName2 = "NotesAPIVM.ps1" 
$localFileApp = $localFileDirectory + $BlobName1 
$localFileApi = $localFileDirectory + $BlobName2

Set-AzureStorageBlobContent -File $localFileApp -Container $storagecontainer -Blob $BlobName1 -Context $ctx
Set-AzureStorageBlobContent -File $localFileApi -Container $storagecontainer -Blob $BlobName2 -Context $ctx

Get-AzureStorageBlobContent -Container $storagecontainer -Context $ctx -Blob $BlobName1

$appblobUrl = "https://"+ $storageaccount + ".blob.core.windows.net/"+$storagecontainer +"/" +$BlobName1
$apiblobUrl = "https://"+ $storageaccount + ".blob.core.windows.net/"+$storagecontainer +"/" +$BlobName2

Write-Host "Blob URL = " $appblobUrl
Write-Host "Blob URL = " $apiblobUrl

#Custom Exception

Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourcegroup `
    -VMName $vmName1  -Name "NotesCustomScript" `
    -FileUri $appblobUrl `
    -Run "NotesAPPVM.ps1" -Location $location

Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourcegroup `
    -VMName $vmName2  -Name "NotesCustomScript" `
    -FileUri $apiblobUrl `
    -Run "NotesAPIVM.ps1" -Location $location  

# Traffic manager
$profile = New-AzureRmTrafficManagerProfile -Name FundooTraffic -ResourceGroupName $resourcegroup -TrafficRoutingMethod Performance -RelativeDnsName fundootraffic -Ttl 30 -MonitorProtocol HTTP -MonitorPort 80 -MonitorPath "/"
$applb = Get-AzureRmPublicIpAddress -Name applbip -ResourceGroupName $resourcegroup
Add-AzureRmTrafficManagerEndpointConfig -EndpointName applbEndpoint -TrafficManagerProfile $profile -Type AzureEndpoints -TargetResourceId $applb.Id -EndpointStatus Enabled
Set-AzureRmTrafficManagerProfile -TrafficManagerProfile $profile






































