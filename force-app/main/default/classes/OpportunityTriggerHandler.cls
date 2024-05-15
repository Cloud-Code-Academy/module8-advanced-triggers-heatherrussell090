public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    public OpportunityTriggerHandler() {
        this.setMaxLoopCount(1);
    }

  
    public static void validateAmount(List<Opportunity> opps) {
        for(Opportunity opp : opps){
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
    }

    public static void setPrimaryContact(List<Opportunity> newOpps) {
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : newOpps){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for(Opportunity opp : newOpps){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }    
    
//Another opportunity Trigger

public static void setType(List<Opportunity> opps) {
    for (Opportunity opp : opps) {   
        if (opp.Type == null){
            opp.Type = 'New Customer';
        } 
    }
}

public static void addStageChangeToDescription(List<Opportunity> opps, Map<Id, Opportunity> oldOppMap) {
    for (Opportunity opp : opps){
        Opportunity oldOpp = oldOppMap.get(opp.Id);
        if (opp.StageName != oldOpp.StageName){
            opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();                    
        }                               
    }
}

public static void validateDelete(List<Opportunity> opps) {
    for (Opportunity oldOpp : opps){
        if (oldOpp.IsClosed){
            oldOpp.addError('Cannot delete closed opportunity');
        }
    }
}

public static void createTaskForOpportunity(List<Opportunity> opps) {
    List<Task> tasksToInsert = new List<Task>();
    for (Opportunity opp : opps) {
        Task tsk = new Task();
        tsk.Subject = 'Call Primary Contact';
        tsk.WhatId = opp.Id;
        tsk.WhoId = opp.Primary_Contact__c;
        tsk.OwnerId = opp.OwnerId;
        tsk.ActivityDate = Date.today().addDays(3);
        tasksToInsert.add(tsk);
    }
    insert tasksToInsert;
}

public static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
    List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
    Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Email FROM User]);
    for (Opportunity opp : opps){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        User oppOwner = userMap.get(opp.OwnerId);
        String[] toAddresses = new String[] {oppOwner.Email};
        mail.setToAddresses(toAddresses);
        mail.setSubject('Opportunity Deleted : ' + opp.Name);
        mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
        mails.add(mail);
    }        
    
    try {
        Messaging.sendEmail(mails);
    } catch (Exception e){
        System.debug('Exception: ' + e.getMessage());
    }
}


public static void closedWonOppDelete(List<Opportunity> opps) {
    Set<Id> accountIds = new Set<Id>();
    for(Opportunity opp : opps) {
        accountIds.add(opp.AccountId);
    }

    Map<Id, Account> accountsMap = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN :accountIds]);

    for(Opportunity opp : opps) {
        if(opp.StageName == 'Closed Won' && accountsMap.get(opp.AccountId).Industry == 'Banking') {
            opp.addError('Cannot delete closed opportunity for a banking account that is won');
        }
    }
}


public static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {    

    Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
    Set<Id> oppAccountIds = new Set<Id>();
    for (Opportunity opp : oppNewMap.values()) {
        oppAccountIds.add(opp.AccountId);
    }
    List<Contact> primaryContacts = [SELECT Id, AccountId 
                                    FROM Contact 
                                    WHERE Title = 'VP Sales' AND AccountId = :oppAccountIds];

        Map<Id, Contact> accountIdToContact = new Map<Id, COntact>();
        for(Contact con : primaryContacts) {
            accountIdToContact.put(con.AccountId, con);
        }       
    
    for(Opportunity opp : oppNewMap.values()) {
        if (opp.Primary_Contact__c == null){
            Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
            Contact primaryContact = accountIdToContact.get(opp.AccountId);
            oppToUpdate.Primary_Contact__c = primaryContact.Id;
            oppMap.put(opp.Id, oppToUpdate);
        }
    }
    update oppMap.values();
}

}





