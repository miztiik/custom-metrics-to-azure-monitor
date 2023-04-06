targetScope = 'subscription'

// Parameters
param deploymentParams object
param rgParams object
param storageAccountParams object
param logAnalyticsWorkspaceParams object
param dceParams object
param vnetParams object
param vmParams object
param brandTags object


var location = deploymentParams.location
var rgName = '${deploymentParams.enterprise_name}_${deploymentParams.enterprise_name_suffix}_${deploymentParams.global_uniqueness}'

param dateNow string = utcNow('yyyy-MM-dd-hh-mm')

param tags object = union(brandTags, {last_deployed:dateNow})

// Create Resource Group
module r_rg 'modules/resource_group/create_rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
    tags:tags
  }
}


// Crate VNets
module r_vnet 'modules/vnet/create_vnet.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${vnetParams.vnetNamePrefix}_${deploymentParams.global_uniqueness}_Vnet'
  params: {
    deploymentParams:deploymentParams
    vnetParams:vnetParams
    tags: tags
  }
  dependsOn: [
    r_rg
  ]
}

// Create Virtual Machine
module r_vm 'modules/vm/create_vm.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${vmParams.vmNamePrefix}_${deploymentParams.global_uniqueness}_Vm'
  params: {
    deploymentParams:deploymentParams
    vmParams: vmParams
    vnetName: r_vnet.outputs.vnetName
    dataCollectionEndpointId: r_dataCollectionEndpoint.outputs.DataCollectionEndpointId
    dataCollectionRuleId: r_dataCollectionRule.outputs.dataCollectionRuleId
    tags: tags
  }
  dependsOn: [
    r_vnet
  ]
}

// Create the Log Analytics Workspace
module r_logAnalyticsWorkspace 'modules/monitor/log_analytics_workspace.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_La'
  params: {
    deploymentParams:deploymentParams
    logAnalyticsWorkspaceParams: logAnalyticsWorkspaceParams
    tags: tags
  }
}

// Create Data Collection Endpoint

module r_dataCollectionEndpoint 'modules/monitor/data_collection_endpoint.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${dceParams.endpointName}_${deploymentParams.global_uniqueness}_dce'
  params: {
    deploymentParams:deploymentParams
    dceParams: dceParams
    osKind: 'linux'
    tags: tags
  }
}


// Create the Data Collection Rule
module r_dataCollectionRule 'modules/monitor/data_collection_rule.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_Dcr'
  params: {
    deploymentParams:deploymentParams
    osKind: 'Linux'
    ruleName: 'webStoreDataCollectorRule'
    logFilePattern: '/var/log/miztiik*.json'
    dataCollectionEndpointId: r_dataCollectionEndpoint.outputs.DataCollectionEndpointId
    customTableNamePrefix: r_logAnalyticsWorkspace.outputs.customTableNamePrefix
    logAnalyticsPayGWorkspaceName:r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceName
    logAnalyticsPayGWorkspaceId:r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    tags: tags
  }
  dependsOn: [
    r_logAnalyticsWorkspace
  ]
}


//Create Fraud Alert
module r_create_fraud_alert 'modules/monitor/create_alert.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_Fraud_Alert'
  params: {
    deploymentParams:deploymentParams
    alertRuleDescription: 'Miztiik Store Fraud Alerts - When order is deeply discounted(>90%), Higher Quantity(>1) and Priority shipping is requested'
    alertRuleName: 'Webstore_Fraud_Alert_${deploymentParams.global_uniqueness}'
    alertRuleDisplayName: 'Miztiik Store Fraud Alerts'
    alertRuleSeverity: 0
    kql_alert_query: '${r_logAnalyticsWorkspace.outputs.customTableName} | where discount > 90 and qty >1 and priority_shipping==true'
    scope_workspaceId_1: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    autoMitigate: true
    evaluationFrequency: 'PT1M' // Choose how often the alert rule should run. If the frequency is smaller than the aggregation granularity, this will result in sliding window evaluation.
    windowSize: 'PT5M' //Aggregation of fraud log window
    tags: tags
  }
  dependsOn: [
    r_logAnalyticsWorkspace
  ]
}


