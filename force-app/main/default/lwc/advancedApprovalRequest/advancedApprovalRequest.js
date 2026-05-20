import { LightningElement, api, track } from 'lwc';
import createApprovalRequest from '@salesforce/apex/ApprovalRequestService.createApprovalRequest';
import getPendingRequests from '@salesforce/apex/ApprovalRequestService.getPendingRequests';

export default class AdvancedApprovalRequest extends LightningElement {
    @api recordId;
    @track approvalRequest;
    @track error;
    @track loading = false;

    connectedCallback() {
        this.loadRequest();
    }

    loadRequest() {
        if (!this.recordId) {
            return;
        }

        this.loading = true;
        getPendingRequests({ targetIds: [this.recordId] })
            .then((requests) => {
                this.approvalRequest = requests.length ? requests[0] : null;
                this.error = undefined;
            })
            .catch((err) => {
                this.error = err;
                this.approvalRequest = null;
            })
            .finally(() => {
                this.loading = false;
            });
    }

    handleStartApproval() {
        this.loading = true;
        createApprovalRequest({
            targetRecordId: this.recordId,
            processId: null,
            requestedById: null
        })
            .then((result) => {
                if (result.success) {
                    this.approvalRequest = { Id: result.approvalRequestId, Status__c: 'Pending' };
                    this.error = undefined;
                } else {
                    this.error = result.message;
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err;
            })
            .finally(() => {
                this.loading = false;
            });
    }
}
