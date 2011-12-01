trigger data_SuppressAccounts on Account (before insert) {
	if(trigger.isBefore && trigger.isInsert) {
		data_ImportSuppressionTriggerHelper.doSuppression();
	}
}