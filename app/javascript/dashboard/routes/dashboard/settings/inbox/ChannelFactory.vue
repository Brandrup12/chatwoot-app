<script>
import { defineComponent, h } from 'vue';
import Facebook from './channels/Facebook.vue';
import Website from './channels/Website.vue';
import Api from './channels/Api.vue';
import Line from './channels/Line.vue';
import Instagram from './channels/Instagram.vue';

const channelViewList = {
  facebook: Facebook,
  website: Website,
  api: Api,
  line: Line,
  instagram: Instagram,
};

export default defineComponent({
  name: 'NewChannelView',
  props: {
    channelName: {
      type: String,
      required: true,
    },
  },
  render() {
    const ChannelComponent = channelViewList[this.channelName];
    return ChannelComponent ? h(ChannelComponent) : null;
  },
});
</script>
