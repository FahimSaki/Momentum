import { Model } from 'mongoose';
import { IUserDocument } from '../types/interfaces';
type UserModel = Model<IUserDocument> & {
    findByInviteId(inviteId: string): Promise<IUserDocument | null>;
    searchUsers(query: string, limit?: number, excludeUserId?: string | null): Promise<IUserDocument[]>;
};
declare const _default: UserModel;
export default _default;
//# sourceMappingURL=User.d.ts.map