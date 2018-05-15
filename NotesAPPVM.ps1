Add-WindowsFeature Web-Server -IncludeManagementTools -includeallsubfeature
Set-WebBinding -Name "Default Web Site" -BindingInformation "*:80:" -PropertyName Port -Value 1234
$rediskey='fundooredis.redis.cache.windows.net:6380,password=2TIr6mEkZwLJi+VmOT2NS+9u9UkHmjtVcN8KXK+LmzM=,ssl=True,abortConnect=False'
$servicebuskey='Endpoint=sb://fundoobus.servicebus.windows.net/;SharedAccessKeyName=ReminderPolicy;SharedAccessKey=XujChsUu789yJmF8T9OGgeEujIgMzwKT7ATDYbTjAbQ=;EntityPath=reminder'
$queuename='reminder'
$BlobContainer='scriptfile'
$BlobAccount='bridgelabzstorage'
$BlobKey='wuBUTHv8lQni2Igv/AQYvWYhawbuw9X/TYjxTtlrcFyMarrCmVBfHSZAFIKIYfJUd58JQDXprw/hz9FhCdTwNA=='
$StoragePath='https://bridgelabzstorage.blob.core.windows.net/'
$DBKey='Server=tcp:fundoo-server.database.windows.net,1433;Initial Catalog=fundoodatabase;Persist Security Info=False;
User ID=devops;Password=Globe@2020;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
$dns='http://apploadbalancerbridge.Westus.cloudapp.azure.com'

[Environment]::SetEnvironmentVariable("FundooDB", $DBKey , "Machine")

[Environment]::SetEnvironmentVariable("RedisCache",$rediskey , "Machine")

[Environment]::SetEnvironmentVariable("ServiceBus",$servicebuskey , "Machine")


[Environment]::SetEnvironmentVariable("BlobAccount", $Blobaccount, "Machine")

[Environment]::SetEnvironmentVariable("BlobKey",$BlobKey, "Machine")

[Environment]::SetEnvironmentVariable("BlobContainer", $BlobContainer, "Machine")

[Environment]::SetEnvironmentVariable("ServiceBus_QueueName", $queuename, "Machine")

[Environment]::SetEnvironmentVariable("StoragePath",$StoragePath, "Machine")

[Environment]::SetEnvironmentVariable("ApiUrl", $dns, "Machine")


[Environment]::SetEnvironmentVariable("AccountSid", "ACad7baba0ab691dd2be127c3b62da30b0", "Machine")

[Environment]::SetEnvironmentVariable("AuthToken", "b7e5d0a14dfb6852cc4decc1cd4308ee", "Machine")

[Environment]::SetEnvironmentVariable("TwilioNumber", "+12052369938 ", "Machine")

[Environment]::SetEnvironmentVariable("RedirectResetUri", "http://localhost:51462/#/reset", "Machine")

[Environment]::SetEnvironmentVariable("RedirectUri", "redirect.html", "Machine")

[Environment]::SetEnvironmentVariable("FBAppID", "142032546517909", "Machine")

[Environment]::SetEnvironmentVariable("FBAppSecret", "f8f720d1dfd54cb541b9923c06406580", "Machine")

[Environment]::SetEnvironmentVariable("GoogleClientId", "255414618812-uh4odb4b622bdahl5kjbsmg1p309gvpk.apps.googleusercontent.com", "Machine")

[Environment]::SetEnvironmentVariable("GoogleClientSecret", "3bowVEMgIoE3Ev62uHVJYxaq", "Machine")

[Environment]::SetEnvironmentVariable("MSClientId", "14da74ed-1810-4326-8906-f8c2757631f0", "Machine")

[Environment]::SetEnvironmentVariable("MSClientSecret", "obxzWDOH48:]kmyTQG150;?", "Machine")

[Environment]::SetEnvironmentVariable("TWConsumerKey", "LJorCIQT6GhMYiRPVqCryjN5x", "Machine")

[Environment]::SetEnvironmentVariable("TWConsumerSecret", "mwWcezInWMeoPshkOSAKQrtRRvolAdFCWQCsaxzJI1FG7IHvQN", "Machine")


[Environment]::SetEnvironmentVariable("SendGridEmail", "bridgelabzsolutions@gmail.com", "Machine")

[Environment]::SetEnvironmentVariable("SendGridAccount", "azure_d22b67ede7d07291b794e214ef768e24@azure.com", "Machine")

[Environment]::SetEnvironmentVariable("SendGridPassword", "Globe@2020", "Machine")
