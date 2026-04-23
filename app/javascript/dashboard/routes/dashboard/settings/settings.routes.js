import { frontendURL } from '../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

import agent from './agents/agent.routes';
import agentBot from './agentBots/agentBot.routes';
import attributes from './attributes/attributes.routes';
import inbox from './inbox/inbox.routes';
import integrations from './integrations/integrations.routes';
import labels from './labels/labels.routes';
import store from '../../../store';
import customRoles from './customRoles/customRole.routes';
import conversationWorkflow from './conversationWorkflow/conversationWorkflow.routes';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings'),
      name: 'settings_home',
      meta: {
        permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
      },
      redirect: to => {
        if (
          store.getters.getCurrentRole === 'administrator' &&
          store.getters.getCurrentCustomRoleId === null
        ) {
          return { name: 'general_settings_index', params: to.params };
        }

        return { name: 'profile_settings_index', params: to.params };
      },
    },
    ...agent.routes,
    ...agentBot.routes,
    ...attributes.routes,
    ...inbox.routes,
    ...integrations.routes,
    ...labels.routes,
    ...customRoles.routes,
    ...conversationWorkflow.routes,
  ],
};
