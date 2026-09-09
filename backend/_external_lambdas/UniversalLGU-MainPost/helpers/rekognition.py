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

def detect_face_liveness(image_bytes):
    """
    Server-side sanity check on the still frame captured at the end of the
    client-side (MediaPipe) gesture challenge. Fail-safe by design: an
    infrastructure failure (Rekognition unreachable/misconfigured) never
    blocks account creation -- it flags needs_review instead. A frame that
    genuinely fails the checks below (bad photo, wrong pose) IS rejected.
    """
    try:
        response = rekognition.detect_faces(
            Image={'Bytes': image_bytes},
            Attributes=['ALL'],
        )
    except Exception as e:
        logger.error(f"detect_face_liveness: Rekognition unreachable: {e}")
        return {'ok': True, 'needs_review': True, 'score': None, 'reason': 'needs_review'}

    faces = response.get('FaceDetails') or []
    if len(faces) != 1:
        reason = 'No face detected' if not faces else 'More than one face detected'
        return {'ok': False, 'needs_review': False, 'score': None, 'reason': reason}

    face = faces[0]
    confidence = face.get('Confidence', 0.0)
    # Sharpness/Brightness live under FaceDetail.Quality in Rekognition's
    # actual response shape, NOT top-level on the face dict -- reading them
    # as face.get('Sharpness')/face.get('Brightness') silently defaulted to
    # 0.0 every single time (confirmed via the diagnostic logging added
    # alongside this fix: real submissions logged confidence=100.00 with
    # sharpness=0.00 brightness=0.00, which is not a real quality reading --
    # it's the missing-key default). This made every genuine submission
    # fail the sharpness/brightness checks unconditionally since launch.
    quality = face.get('Quality', {})
    sharpness = quality.get('Sharpness', 0.0)
    brightness = quality.get('Brightness', 0.0)
    pose = face.get('Pose', {})
    yaw, pitch, roll = abs(pose.get('Yaw', 0.0)), abs(pose.get('Pitch', 0.0)), abs(pose.get('Roll', 0.0))
    eyes_open = face.get('EyesOpen', {})

    checks = [
        confidence >= 90.0,
        sharpness >= 20.0,
        25.0 <= brightness <= 95.0,
        yaw <= 30.0 and pitch <= 30.0 and roll <= 30.0,
        eyes_open.get('Value', True) or eyes_open.get('Confidence', 0.0) < 60.0,
    ]
    if not all(checks):
        # Logged so a real rejection can actually be diagnosed -- until this,
        # every failure surfaced client-side only as the generic "Liveness
        # check failed" with no record of which check tripped or by how much.
        logger.info(
            "detect_face_liveness rejected: confidence=%.2f sharpness=%.2f "
            "brightness=%.2f yaw=%.2f pitch=%.2f roll=%.2f eyes_open=%s "
            "eyes_open_confidence=%.2f checks=%s",
            confidence, sharpness, brightness, yaw, pitch, roll,
            eyes_open.get('Value'), eyes_open.get('Confidence', 0.0), checks,
        )
        return {'ok': False, 'needs_review': False, 'score': None, 'reason': 'Liveness check failed'}

    pose_score = max(0.0, 100.0 - (yaw + pitch + roll))
    score = round(0.50 * confidence + 0.25 * sharpness + 0.25 * pose_score, 2)
    return {'ok': True, 'needs_review': False, 'score': score, 'reason': None}
