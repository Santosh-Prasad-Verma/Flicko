import type { Meta, StoryObj } from '@storybook/react';
import { TypingIndicator } from './TypingIndicator';

const meta: Meta<typeof TypingIndicator> = {
  title: 'Messages/TypingIndicator',
  component: TypingIndicator,
  argTypes: {
    usernames: {
      control: 'object',
      description: 'Array of usernames currently typing',
    },
  },
};

export default meta;

type Story = StoryObj<typeof TypingIndicator>;

export const SingleUser: Story = {
  args: {
    usernames: ['Alice'],
  },
};

export const TwoUsers: Story = {
  args: {
    usernames: ['Alice', 'Bob'],
  },
};

export const ManyUsers: Story = {
  args: {
    usernames: ['Alice', 'Bob', 'Charlie', 'Dave'],
  },
};

export const NoUsers: Story = {
  args: {
    usernames: [],
  },
};
