import { ref, computed } from 'vue';

// Stub composable after Captain feature was stripped
export const useCaptain = () => ({
  captainEnabled: computed(() => false),
  captainLimits: ref({}),
  documentLimits: ref({}),
  responseLimits: ref({}),
  fetchLimits: () => {},
  isFetchingLimits: ref(false),
  isCaptainEnabled: computed(() => false),
  captainTasksEnabled: computed(() => false),
  assistants: ref([]),
  fetchAssistants: () => {},
});

export default useCaptain;
