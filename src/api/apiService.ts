// apiService.ts
import axios from 'axios';

export async function fetchSvdeAgentId(entityId: string) {
  try {
    const response = await axios.get('http://localhost:5000/qid2svde', {
      params: {
        qid: entityId,
      },
    });
    return response.data.svde_agent_id;
  } catch (error) {
    console.error(error);
  }
}

export async function fetchWorks(svdeAgentId: string) {
  try {
    const response = await axios.get('http://localhost:5000/agent2opus', {
      params: {
        svde_agent: svdeAgentId,
      },
    });
    return response.data;
  } catch (error) {
    console.error(error);
  }
}