trigger data_SuppressLeads on Lead (before insert) {
	if(trigger.isBefore && trigger.isInsert) {
		data_ImportSuppressionTriggerHelper.doSuppression();
	}
}