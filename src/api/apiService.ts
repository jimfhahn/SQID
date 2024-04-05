// apiService.ts
import axios from 'axios';

export async function fetchSvdeAgentId(entityId) {
  try {
    const response = await axios.get('http://localhost:5000/qid2svde', {
      params: {
        qid: entityId,
      },
    });
    return response.data.svde_agent_uri; 
  } catch (error) {
    console.error(error);
  }
}