import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getServers, getServer, createServer, updateServer, deleteServer } from '@shared/services/serverService';
import type { CreateServerInput, UpdateServerInput } from '@shared/services/serverService';

export function useServers() {
    return useQuery({
        queryKey: ['servers'],
        queryFn: getServers,
        staleTime: 5 * 60 * 1000,
    });
}

export function useServer(serverId: string | null) {
    return useQuery({
        queryKey: ['server', serverId],
        queryFn: () => getServer(serverId!),
        enabled: !!serverId,
        staleTime: 5 * 60 * 1000,
    });
}

export function useCreateServer() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: (input: CreateServerInput) => createServer(input),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['servers'] });
        },
    });
}

export function useUpdateServer() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: ({ serverId, input }: { serverId: string; input: UpdateServerInput }) =>
            updateServer(serverId, input),
        onSuccess: (_data, variables) => {
            queryClient.invalidateQueries({ queryKey: ['servers'] });
            queryClient.invalidateQueries({ queryKey: ['server', variables.serverId] });
        },
    });
}

export function useDeleteServer() {
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: (serverId: string) => deleteServer(serverId),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['servers'] });
        },
    });
}
