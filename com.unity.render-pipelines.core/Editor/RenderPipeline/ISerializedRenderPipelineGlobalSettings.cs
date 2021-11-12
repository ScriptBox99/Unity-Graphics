namespace UnityEditor.Rendering
{
    /// <summary>
    /// Interface for objects that wrap a <see cref="SerializedObject"/> of a <see cref="UnityEngine.Rendering.RenderPipelineGlobalSettings"/>
    /// </summary>
    public interface ISerializedRenderPipelineGlobalSettings
    {
        /// <summary>
        /// The <see cref="SerializedObject"/>
        /// </summary>
        public SerializedObject serializedObject { get; }
    }
}
