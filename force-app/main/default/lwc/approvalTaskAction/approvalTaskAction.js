import { LightningElement, api, track } from 'lwc';
import approveTask from '@salesforce/apex/ApprovalTaskService.approveTask';
import rejectTask from '@salesforce/apex/ApprovalTaskService.rejectTask';

export default class ApprovalTaskAction extends LightningElement {
    @api taskId;
    @track error;
    @track working = false;

    handleApprove() {
        this.working = true;
        approveTask({ taskId: this.taskId, comments: 'Approved via Lightning action' })
            .then(() => {
                this.dispatchEvent(new CustomEvent('refresh'));
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err;
            })
            .finally(() => {
                this.working = false;
            });
    }

    handleReject() {
        this.working = true;
        rejectTask({ taskId: this.taskId, comments: 'Rejected via Lightning action' })
            .then(() => {
                this.dispatchEvent(new CustomEvent('refresh'));
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err;
            })
            .finally(() => {
                this.working = false;
            });
    }
}
