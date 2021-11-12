using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UIElements;

namespace UnityEditor.Rendering
{
    /// <summary>
    /// Render Pipeline Settings provider
    /// </summary>
    /// <typeparam name="TRenderPipeline"><see cref="RenderPipeline"/></typeparam>
    /// <typeparam name="TGlobalSettings"><see cref="RenderPipelineGlobalSettings"/></typeparam>
    /// <typeparam name="TSerializedSettings"><see cref="ISerializedRenderPipelineGlobalSettings"/></typeparam>
    public abstract class RenderPipelineGlobalSettingsProvider<TRenderPipeline, TGlobalSettings, TSerializedSettings> : SettingsProvider
        where TRenderPipeline : RenderPipeline
        where TGlobalSettings : RenderPipelineGlobalSettings
        where TSerializedSettings : ISerializedRenderPipelineGlobalSettings
    {
        static class Styles
        {
            public static readonly string warningGlobalSettingsMissing = "Select a valid {0} asset. There might be issues in rendering.";
            public static readonly string warningSRPNotActive = "Current Render Pipeline is not {0}. Check the settings: Graphics > Scriptable Render Pipeline Settings, Quality > Render Pipeline Asset.";

            public static readonly GUIContent newAssetButtonLabel = EditorGUIUtility.TrTextContent("New", "Create a Global Settings asset in the Assets folder.");
            public static readonly GUIContent cloneAssetButtonLabel = EditorGUIUtility.TrTextContent("Clone", "Clone a Global Settings asset in the Assets folder.");
        }

        Editor m_Editor;
        ISerializedRenderPipelineGlobalSettings m_SerializedSettings;
        TGlobalSettings m_GlobalSettings;

        TGlobalSettings cachedSettings => GraphicsSettings.GetSettingsForRenderPipeline<TRenderPipeline>() as TGlobalSettings;

        public RenderPipelineGlobalSettingsProvider(string v, SettingsScope project)
            : base(v, project)
        {
        }

        void DestroyEditor()
        {
            if (m_Editor != null)
            {
                UnityEngine.Object.DestroyImmediate(m_Editor);
            }

            m_Editor = null;
        }

        /// <summary>
        /// This method is being called when the provider is activated
        /// </summary>
        /// <param name="searchContext">The context with the search</param>
        /// <param name="rootElement">The <see cref="VisualElement"/> with the root</param>
        public override void OnActivate(string searchContext, VisualElement rootElement)
        {
            DestroyEditor();
            base.OnActivate(searchContext, rootElement);
        }

        /// <summary>
        /// This method is being called when the provider is deactivated
        /// </summary>
        public override void OnDeactivate()
        {
            DestroyEditor();
            base.OnDeactivate();
        }

        /// <summary>
        /// Ensures that the <see cref="RenderPipelineGlobalSettings"/> asset is correct
        /// </summary>
        protected abstract void Ensure();

        /// <summary>
        /// Creates a new <see cref="RenderPipelineGlobalSettings"/> asset
        /// </summary>
        protected abstract void Create(bool useProjectSettingsFolder, bool activateAsset);

        /// <summary>
        /// Clones the <see cref="RenderPipelineGlobalSettings"/> asset
        /// </summary>
        protected abstract void Clone(TGlobalSettings src, bool activateAsset);

        /// <summary>
        /// Updates the Graphics settings with the selected <see cref="RenderPipelineGlobalSettings"/> asset
        /// </summary>
        protected abstract void UpdateGraphicsSettings(TGlobalSettings newSettings);

        /// <summary>
        /// Refreshes the settings in case they are null
        /// </summary>
        /// <param name="settingsSerialized"><see cref="RenderPipelineGlobalSettings"/></param>
        /// <param name="serializedSettings"><see cref="ISerializedRenderPipelineGlobalSettings"/></param>
        protected abstract void Refresh(ref TGlobalSettings settingsSerialized, ref ISerializedRenderPipelineGlobalSettings serializedSettings);

        /// <summary>
        /// Method called to render the IMGUI of the settings provider
        /// </summary>
        /// <param name="searchContext">The search content</param>
        public override void OnGUI(string searchContext)
        {
            // When the asset being serialized has been deleted before its reconstruction
            if (m_SerializedSettings != null && m_SerializedSettings.serializedObject.targetObject == null)
            {
                m_SerializedSettings = null;
                m_GlobalSettings = null;
                m_Editor = null;
            }

            if (m_SerializedSettings == null || m_GlobalSettings != cachedSettings)
            {
                if (cachedSettings != null)
                {
                    Refresh(ref m_GlobalSettings, ref m_SerializedSettings);
                }
                else
                {
                    m_SerializedSettings = null;
                    m_GlobalSettings = null;
                    m_Editor = null;
                }
            }
            else if (m_GlobalSettings != null && m_SerializedSettings != null)
            {
                m_SerializedSettings.serializedObject.Update();
            }

            using (new SettingsProviderGUIScope())
            {
                DrawAssetSelection();

                if (!(RenderPipelineManager.currentPipeline is TRenderPipeline))
                {
                    EditorGUILayout.HelpBox(string.Format(Styles.warningSRPNotActive, ObjectNames.NicifyVariableName(typeof(TRenderPipeline).Name)), MessageType.Warning);
                }

                if (m_GlobalSettings == null)
                {
                    CoreEditorUtils.DrawFixMeBox(string.Format(Styles.warningGlobalSettingsMissing, ObjectNames.NicifyVariableName(typeof(TGlobalSettings).Name)), () => Ensure());
                }
                else if(m_SerializedSettings != null)
                {
                    if (m_Editor == null)
                        m_Editor = Editor.CreateEditor(m_SerializedSettings.serializedObject.targetObject);

                    m_Editor.OnInspectorGUI();

                    m_SerializedSettings.serializedObject?.ApplyModifiedProperties();
                }
            }

            base.OnGUI(searchContext);
        }

        void DrawAssetSelection()
        {
            using (new EditorGUILayout.HorizontalScope())
            {
                EditorGUI.BeginChangeCheck();
                var newAsset = (TGlobalSettings)EditorGUILayout.ObjectField(m_GlobalSettings, typeof(TGlobalSettings), false);
                if (EditorGUI.EndChangeCheck())
                {
                    UpdateGraphicsSettings(newAsset);
                    if (m_GlobalSettings != null && !m_GlobalSettings.Equals(null))
                        EditorUtility.SetDirty(m_GlobalSettings);
                }

                if (GUILayout.Button(Styles.newAssetButtonLabel, GUILayout.Width(45), GUILayout.Height(18)))
                {
                    Create(useProjectSettingsFolder: true, activateAsset: true);
                }

                bool guiEnabled = GUI.enabled;
                GUI.enabled = guiEnabled && (m_GlobalSettings != null);
                if (GUILayout.Button(Styles.cloneAssetButtonLabel, GUILayout.Width(45), GUILayout.Height(18)))
                {
                    Clone(m_GlobalSettings, activateAsset: true);
                }
                GUI.enabled = guiEnabled;
            }
        }
    }
}
