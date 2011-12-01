public without sharing class data_ImportSetting {

	public Id sId;
	public Id sPermId;
	public String sType;
	public String sName;
	public String sController;
	public Boolean sAccountImportDisabled;
	public Boolean sContactImportDisabled;
	public Boolean sLeadImportDisabled;
	
	public Id getsId() {
		return this.sId;
	}
	
	public Id getsPermId() {
		return this.sPermId;
	}
	
	public String getsType() {
		return this.sType;
	}
	
	public String getsName() {
		return this.sName;
	}
	
	public String getsController() {
		return this.sController;
	}
	
	public Boolean getsAccountImportDisabled() {
		return this.sAccountImportDisabled;
	}
	
	public void setsAccountImportDisabled(Boolean sAccountImportDisabled) {
		this.sAccountImportDisabled = sAccountImportDisabled;
	}
	
	public Boolean getsContactImportDisabled() {
		return this.sContactImportDisabled;
	}
	
	public void setsContactImportDisabled(Boolean sContactImportDisabled) {
		this.sContactImportDisabled = sContactImportDisabled;
	}
	
	public Boolean getsLeadImportDisabled() {
		return this.sLeadImportDisabled;
	}
	
	public void setsLeadImportDisabled(Boolean sLeadImportDisabled) {
		this.sLeadImportDisabled = sLeadImportDisabled;
	}
}