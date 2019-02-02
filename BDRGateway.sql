SET NOCOUNT ON;
SELECT SUBSTRING(
(SELECT connectionGatewayIp + ',' + ComputerName + '+'
FROM (
	SELECT ComputerName, connectionGatewayIp,	Row_number() OVER(PARTITION BY connectionGatewayIP ORDER BY connectionGatewayIp) rn
	FROM [dbo].[vAuditMachineSummary] JOIN [ksubscribers].[api].[vw_GetAuditInstalledApplications] 
	on [dbo].[vAuditMachineSummary].agentGuid = [ksubscribers].[api].[vw_GetAuditInstalledApplications].agentGuid
	WHERE applicationName = 'Veeam.Backup.Service.exe' 
	AND version > '6' 
	AND NOT ComputerName IN ('ServerExclude1', 'ServerExclude2', 'ServerExclude3')) t				
WHERE rn = 1
ORDER BY ComputerName
FOR XML PATH('')),1,2000000) AS XML
GO