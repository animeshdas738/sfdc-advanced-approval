import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyTaskContext from '@salesforce/apex/ApprovalTaskService.getMyTaskContext';
import approveTask from '@salesforce/apex/ApprovalTaskService.approveTask';
import rejectTask from '@salesforce/apex/ApprovalTaskService.rejectTask';

export default class ApprovalTaskAction extends LightningElement {
    @api recordId;
    @track error;
    @track working = false;

    _wiredCtx;

    @wire(getMyTaskContext, { recordId: '$recordId' })
    wiredCtxResult(result) {
        this._wiredCtx = result;
        if (result.error) {
            this.error = result.error.body?.message ?? String(result.error);
        }
    }

    get loading() {
        return !this._wiredCtx || (this._wiredCtx.data === undefined && !this._wiredCtx.error);
    }

    get ctx() {
        return this._wiredCtx?.data ?? null;
    }

    // Pending request exists for this record
    get requestExists() {
        return this.ctx?.requestExists === true;
    }

    // Current user is an assigned approver with an open task
    get isAssignee() {
        return this.ctx?.isAssignee === true;
    }

    get taskId() {
        return this.ctx?.task?.Id;
    }

    get assigneeName() {
        return this.ctx?.task?.Assignee__r?.Name;
    }

    handleApprove() {
        this._act(approveTask, 'Approved via Lightning action');
    }

    handleReject() {
        this._act(rejectTask, 'Rejected via Lightning action');
    }

    _act(action, comments) {
        if (!this.taskId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Not an assigned approver',
                message: 'You do not have an open approval task assigned to you for this record.',
                variant: 'error',
                mode: 'sticky'
            }));
            return;
        }
        this.working = true;
        this.error = null;
        action({ taskId: this.taskId, comments })
            .then(() => refreshApex(this._wiredCtx))
            .then(() => this.dispatchEvent(new CustomEvent('refresh')))
            .catch((err) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Action failed',
                    message: err.body?.message ?? String(err),
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.working = false;
            });
    }
}
