import logging
import boto3

logger = logging.getLogger()
rekognition = boto3.client('rekognition')

def compare_faces(source_bytes, target_bytes, threshold=60):
    try:
        response = rekognition.compare_faces(
            SourceImage={'Bytes': source_bytes},
            TargetImage={'Bytes': target_bytes},
            SimilarityThreshold=threshold,
        )
        if response.get('FaceMatches'):
            best = max(response['FaceMatches'], key=lambda m: m['Similarity'])
            return {'status': True, 'similarity': round(best['Similarity'], 2), 'message': 'Face match found'}
        return {'status': False, 'similarity': 0, 'message': 'No face match found'}
    except Exception as e:
        logger.error(f"Rekognition error: {e}")
        return {'status': False, 'similarity': 0, 'message': f'Error comparing faces: {str(e)}'}
