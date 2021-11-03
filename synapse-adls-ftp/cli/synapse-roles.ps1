# Supporting commands intended for use within a DevOps pipeline to create required Synapse roles

param ($synapseWorkspaceName, $dataEngineersAADGroupObjectID, $infraAdminsAADGroupObjectID)

az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse Administrator" --assignee $dataEngineersAADGroupObjectID
az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse Linked Data Manager" --assignee $infraAdminsAADGroupObjectID
