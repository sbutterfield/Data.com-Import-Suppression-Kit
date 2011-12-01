trigger data_SuppressContacts on Contact (before insert) {
	if(trigger.isBefore && trigger.isInsert) {
		data_ImportSuppressionTriggerHelper.doSuppression();
	}
}