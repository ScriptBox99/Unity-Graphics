using UnityEngine.Experimental.Rendering;

namespace UnityEditor.Experimental.Rendering
{
    [CustomEditor(typeof(ProbeVolumeAsset))]
    class ProbeVolumeAssetEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            using (new EditorGUI.DisabledScope(true))
                base.OnInspectorGUI();
        }
    }
}
